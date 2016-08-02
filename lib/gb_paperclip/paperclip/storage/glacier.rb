module Paperclip
  module Storage
    # Amazon Glacier is a part of AWS cloud. In contrast to Amazon S3 storage
    # is design to cheap storing files, but it provide very slow data access.
    # Retrieving file can usually take between 3 and 6 hours. Beacuse of this, it is "write only" storage.
    # This storage is design to be used as an backup - it should be used only together with #{Paperclip::Storage::MultipleStorage},
    # but never as main store.
    #
    # Usage of this store require additional field on your model - +glacier_ids+.
    # It have to be field which can be used as Hash. It can be field define as hstore or
    # String file serialized to Hash.
    #
    # Glacier storage is based on Fog storage, so it have very similar config.
    # * +glacier_credentials+: Takes a Hash with your credentials. For S3,
    #   you can use the following format:
    #     aws_access_key_id: '<your aws_access_key_id>'
    #     aws_secret_access_key: '<your aws_secret_access_key>'
    #     region: 'eu-west-1'
    # * +vault+: Should be inside credentials. This is the name of the name of the vault that will
    #   store your files.  Remember that the vault must be unique across
    #   all of Amazon Glacier. If the vault does not exist, Paperclip will
    #   attempt to create it.
    # * +path+: This is the key under the vault in which the file will
    #   be stored. This will map proper glacier id with file. Also path will
    #   be used as an description of archive.
    # * +glacier_region+ Amazon region.
    module Glacier

      def self.extended base
        begin
          require 'aws-sdk'
        rescue LoadError => e
          e.message << " (You may need to install the aws-sdk gem)"
          raise e
        end unless defined?(Aws::Glacier::Client)

        base.instance_eval do
          @glacier_options = @options[:s3_options] || {}
          @http_proxy      = @options[:http_proxy] || nil
        end
      end

      def parse_credentials creds
        creds = creds.respond_to?('call') ? creds.call(self) : creds
        creds = find_credentials(creds).stringify_keys
        env   = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def glacier_instances
        Thread.current[:glacier_instances] ||= Hash.new
      end

      def glacier_credentials
        @glacier_credentials ||= parse_credentials(@options[:glacier_credentials])
      end

      def glacier_region
        host_name = @options[:glacier_region]
        host_name = host_name.call(self) if host_name.is_a?(Proc)

        host_name || glacier_credentials[:glacier_region] || 'us-west-1'
      end

      def vault_name
        @vault = @options[:vault] || glacier_credentials[:vault]
        @vault = @vault.call(self) if @vault.respond_to?(:call)
        @vault or raise ArgumentError, 'missing required :vault option'
      end

      def account_id
        @vault = @options[:account_id] || glacier_credentials[:account_id]
        @vault = @vault.call(self) if @vault.respond_to?(:call)
        @vault or raise ArgumentError, 'missing required :account_id option'
      end

      # @return [Aws::Glacier::Client]
      def glacier_interface
        @glacier_interface ||= begin
          config = { :region => glacier_region }

          if using_http_proxy?

            proxy_opts        = { :host => http_proxy_host }
            proxy_opts[:port] = http_proxy_port if http_proxy_port
            if http_proxy_user
              userinfo              = http_proxy_user.to_s
              userinfo              += ":#{http_proxy_password}" if http_proxy_password
              proxy_opts[:userinfo] = userinfo
            end
            config[:proxy_uri] = URI::HTTP.build(proxy_opts)
          end

          [:access_key_id, :secret_access_key, :credential_provider].each do |opt|
            config[opt] = glacier_credentials[opt] if glacier_credentials[opt]
          end

          obtain_glacier_instance_for(config.merge(@glacier_options))
        end
      end

      def glacier_resource
        @glacier_resource ||= Aws::Glacier::Resource.new(client: glacier_interface)
      end

      # @return [Aws::Glacier::Client]
      def obtain_glacier_instance_for(options)
        glacier_instances[options] ||= Aws::Glacier::Client.new(options)
      end

      # @return [AWS::Glacier::Vault]
      def glacier_vault
        @glacier_vault ||= glacier_resource.account(account_id).vault(vault_name)
      end

      def using_http_proxy?
        !!@http_proxy
      end

      def http_proxy_host
        using_http_proxy? ? @http_proxy[:host] : nil
      end

      def http_proxy_port
        using_http_proxy? ? @http_proxy[:port] : nil
      end

      def http_proxy_user
        using_http_proxy? ? @http_proxy[:user] : nil
      end

      def http_proxy_password
        using_http_proxy? ? @http_proxy[:password] : nil
      end

      def glacier_ids
        instance.glacier_ids || Hash.new
      end


      def find_credentials(creds)
        case creds
          when File
            YAML::load(ERB.new(File.read(creds.path)).result)
          when String, Pathname
            YAML::load(ERB.new(File.read(creds)).result)
          when Hash
            creds
          when NilClass
            {}
          else
            raise ArgumentError, "Credentials given are not a path, file, proc, or hash."
        end
      end

      # @return [Aws::Glacier::Vault]
      def create_vault
        glacier_resource.account(account_id).create_vault :vault_name => vault_name
      end

      public

      def exists?(style = default_style) #:nodoc:
        raise ArgumentError.new('Model need to have :glacier_id string field!') unless instance.respond_to? :glacier_ids
        if glacier_ids
          !!glacier_ids[path(style)]
        else
          false
        end
      end

      def flush_writes #:nodoc:
        raise ArgumentError.new('Model need to have :glacier_id string field!') unless instance.respond_to? :glacier_ids
        @queued_for_write.each do |style, file|
          log("saving to glacier #{path(style)}")
          retries = 0
          begin
            retries += 1
            archive = glacier_vault.upload_archive(body: file, archive_description: path(style).to_s)
            instance.update_column(:glacier_ids, Hash.new.merge(glacier_ids).merge(path(style).sub(%r{\A/},'' => archive.id)))
          rescue Aws::Glacier::Errors::ResourceNotFoundException
            create_vault
            retry
          rescue Aws::Glacier::Errors::ServiceError => e
            log "Amazon glacier SD #{e.message}"
            if retries <= 5
              sleep((2 ** retries) * 0.5)
              retry
            else
              raise
            end
          rescue Aws::Glacier::Errors::RequestTimeoutException
            if retries <= 1
              retry
            else
              raise
            end
          ensure
            file.rewind
          end
        end

        after_flush_write

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        raise ArgumentError.new('Model need to have :glacier_ids string field!') unless instance.respond_to? :glacier_ids
        for path in @queued_for_delete do
          next unless glacier_ids && glacier_ids[path]
          log("deleting from glacier #{path}")
          glacier_vault.archive(glacier_ids[path]).delete
          new_ids = Hash.new.merge glacier_ids
          new_ids.delete path
          begin
            instance.update_column(:glacier_ids, new_ids)
          rescue
            nil
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path) #:nodoc:
        raise ArgumentError.new('Model need to have :glacier_id string field!') unless instance.respond_to? :glacier_ids
        raise Exception.new 'Write only storage! you can retrieve file asynchronously!'
      end
    end
  end
end