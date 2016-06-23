module Paperclip
  module Storage
    # Amazon Glacier is a part of AWS cloud. In contrast to Amazon S3 storage
    # is design to cheap storing files, but it provide very slow data access.
    # Retrieving file can usually take between 3 and 6 hours. Because of this, it is "write only" storage.
    # This storage is design to be used as an backup - it should be used only together with #{Paperclip::Storage::MultipleStorage},
    # but never as main store.
    #
    # Usage of this store require additional field on your model - +glacier_ids+.
    # It have to be field which can be used as Hash. It can be field define as hstore or
    # String file serialized to Hash.
    #
    # Glacier storage is based on Fog storage, so it have very similar config.
    # * +fog_credentials+: Takes a Hash with your credentials. For S3,
    #   you can use the following format:
    #     aws_access_key_id: '<your aws_access_key_id>'
    #     aws_secret_access_key: '<your aws_secret_access_key>'
    #     region: 'eu-west-1'
    # * +fog_directory+: This is the name of the name of the vault that will
    #   store your files.  Remember that the vault must be unique across
    #   all of Amazon Glacier. If the vault does not exist, Paperclip will
    #   attempt to create it.
    # * +path+: This is the key under the bucket in which the file will
    #   be stored. This will map proper glacier id with file. Also path will
    #   be used as an description of archive.
    module GlacierFog

      def self.extended(base)
        begin
          require 'fog'
        rescue LoadError => e
          e.message << ' (You may need to install the fog gem)'
          raise e
        end unless defined?(Fog)
      end

      def parse_credentials(creds)
        creds = find_credentials(creds).stringify_keys
        env   = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def fog_credentials
        @fog_credentials ||= parse_credentials(@options[:fog_credentials])
      end

      # @return [Fog::AWS::Glacier::Vault]
      def vault
        dir    = if @options[:fog_directory].respond_to?(:call)
                   @options[:fog_directory].call(self)
                 else
                   @options[:fog_directory]
                 end
        @vault ||= connection.vaults.new(:id => dir)
      end

      def connection
        @connection ||= ::Fog::AWS::Glacier.new(fog_credentials)
      end

      def glacier_ids
        instance.glacier_ids
      end

      def find_credentials(creds)
        case creds
          when File
            YAML::load(ERB.new(File.read(creds.path)).result)
          when String, Pathname
            YAML::load(ERB.new(File.read(creds)).result)
          when Hash
            creds
          else
            if creds.respond_to?(:call)
              creds.call(self)
            else
              raise ArgumentError, 'Credentials are not a path, file, hash or proc.'
            end
        end
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
          retried = false
          begin
            archive = vault.archives.create(
                body:                 file,
                description:          path(style),
                multipart_chunk_size: 1024*1024*2
            )
            instance.update_column(:glacier_ids, (glacier_ids || Hash.new).merge(path(style) => archive.id))
          rescue Excon::Errors::NotFound
            raise if retried
            retried = true
            vault.save
            retry
          ensure
            file.rewind
          end
        end

        after_flush_writes

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        raise ArgumentError.new('Model need to have :glacier_id string field!') unless instance.respond_to? :glacier_ids
        @queued_for_delete.each do |path|
          next unless glacier_ids && glacier_ids[path]
          log("deleting from glacier #{path}")
          vault.archives.new(:id => glacier_ids[path]).destroy
          new_ids = glacier_ids.clone
          new_ids.delete path
          begin
            instance.update_column(:glacier_ids, new_ids)
          rescue
            nil
          end
        end
        @queued_for_delete = []
      end

      # noinspection RubyUnusedLocalVariable
      def copy_to_local_file(style, local_dest_path) #:nodoc:
        raise ArgumentError.neśw('Model need to have :glacier_id string field!') unless instance.respond_to? :glacier_ids
        raise Exception.new 'Write only storage! you can retrieve file asynchronously!'
      end
    end

    # Asynchronously copy file to local path and call success śblock. Success block can have one param - it is an exception.
    # When everything succeeded, param will be an +false+ value, other else it will exception object.
    # Success block will be usually called after 3-6 hours.
    # @example example usage
    #   copy_async_local_file(:original, 'tmp/tmp_file') do |error|
    #     if error
    #       handle error
    #     else
    #       handle_success
    #     end
    #   end
    def copy_async_local_file(style, local_dest_path, &success)
      remote_path = path(style)
      return false unless glacier_ids[remote_path]
      Thread.new do
        begin
          job = vault.jobs.create(:type => Fog::AWS::Glacier::Job::ARCHIVE, :archive_id => glacier_ids[remote_path])
          until job.ready?
            sleep 360.0
          end
          File.open(local_dest_path) do |f|
            job.get_output :io => f
          end
          success.call(false)
        rescue Exception => e
          success.call(e)
        end
      end
    end
  end
end