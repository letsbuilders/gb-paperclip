module Paperclip
  class AbstractAdapter
    # @return [Tempfile]
    def to_tempfile
      @tempfile
    end
  end

  module Storage
    module S3V2
      @@s3_instances = Hash.new
      @@s3_lock      = Mutex.new

      def self.extended(base)
        begin
          require 'aws-sdk'
        rescue LoadError => e
          e.message << " (You may need to install the aws-sdk gem)"
          raise e
        end unless defined?(Aws::S3::Client)

        base.instance_eval do
          @s3_options     = @options[:s3_options] || {}
          @s3_permissions = set_permissions(@options[:s3_permissions])
          @s3_protocol    = @options[:s3_protocol] ||
              Proc.new do |style, attachment|
                permission = (@s3_permissions[style.to_s.to_sym] || @s3_permissions[:default])
                permission = permission.call(attachment, style) if permission.respond_to?(:call)
                (permission == :public_read) ? 'http' : 'https'
              end
          @s3_metadata    = @options[:s3_metadata] || {}
          @s3_headers     = {}
          merge_s3_headers(@options[:s3_headers], @s3_headers, @s3_metadata)

          @s3_storage_class = set_storage_class(@options[:s3_storage_class])

          @s3_server_side_encryption = :aes256
          if @options[:s3_server_side_encryption].blank?
            @s3_server_side_encryption = false
          end
          if @s3_server_side_encryption
            @s3_server_side_encryption = @options[:s3_server_side_encryption]
          end

          unless @options[:url].to_s.match(/\A:s3.*url\Z/) || @options[:url] == ":asset_host"
            @options[:path] = path_option.gsub(/:url/, @options[:url]).gsub(/\A:rails_root\/public\/system/, '')
            @options[:url]  = ":s3_path_url"
          end
          @options[:url] = @options[:url].inspect if @options[:url].is_a?(Symbol)

          @http_proxy = @options[:http_proxy] || nil
        end

        Paperclip.interpolates(:s3_alias_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.s3_host_alias}/#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_alias_url
        Paperclip.interpolates(:s3_path_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.s3_host_name}/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_path_url
        Paperclip.interpolates(:s3_domain_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.bucket_name}.#{attachment.s3_host_name}/#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_domain_url
        Paperclip.interpolates(:asset_host) do |attachment, style|
          "#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :asset_host
      end

      # @return [Hash]
      def s3_instances
        @@s3_instances
      end

      # @return [Mutex]
      def s3_lock
        @@s3_lock
      end

      def obtain_s3_instance_for(options)
        s3_lock.lock
        result = s3_instances[options] ||= Aws::S3::Client.new(options)
        s3_lock.unlock
        result
      end

      # @return [Aws::S3::Client]
      def s3_client
        @s3_client ||= begin
          config = { :region => s3_region }

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
            config[opt] = s3_credentials[opt] if s3_credentials[opt]
          end

          obtain_s3_instance_for(config.merge(@s3_options))
        end
      end

      def s3_resource
        @s3_resource ||= Aws::S3::Resource.new(client: s3_client)
      end

      def s3_region
        region = nil
        if @options[:s3_region]
          region = @options[:s3_region]
          region = region.call(self) if @region.is_a?(Proc)
        elsif s3_credentials[:s3_region]
          region = s3_credentials[:s3_region]
        elsif @options[:s3_host_name]
          region = s3_host_name.split('.').first
          region = region.split('-')
          region.delete_if { |str| str == 's3' }
          region = region.join('-')
        end
        region
      end

      # Generates authenticated url valid for given time with given name
      # @param time [Fixnum] seconds of link validity. Default 3600
      # @param file_name [String] name, how file with be saved.
      # @param style_name [String] style, for which url should be generated
      # @return [String]
      def expiring_url_with_name(time = 3600, file_name = nil, style_name = default_style)
        if path(style_name)
          base_options = { :expires_in => time, :secure => use_secure_protocol?(style_name) }
          if file_name
            base_options[:response_content_disposition] = "attachment;filename=\"#{file_name}\";"
          end
          s3_object(style_name).presigned_url(:get, base_options.merge(s3_url_options)).to_s
        else
          url(style_name)
        end
      end

      # @return [IO]
      def get_file_stream(style_name = default_style)
        s3_client.get_object(bucket: bucket_name, key: path(style_name).sub(%r{\A/}, '')).body
      end

      def expiring_url(time = 3600, style_name = default_style)
        if path(style_name)
          base_options = { :expires_in => time, :secure => use_secure_protocol?(style_name) }
          s3_object(style_name).presigned_url(:get, base_options.merge(s3_url_options)).to_s
        else
          url(style_name)
        end
      end

      def s3_credentials
        @s3_credentials ||= parse_credentials(@options[:s3_credentials])
      end

      def s3_host_name
        host_name = @options[:s3_host_name]
        host_name = host_name.call(self) if host_name.is_a?(Proc)

        host_name || s3_credentials[:s3_host_name] || "s3.amazonaws.com"
      end

      def s3_host_alias
        @s3_host_alias = @options[:s3_host_alias]
        @s3_host_alias = @s3_host_alias.call(self) if @s3_host_alias.respond_to?(:call)
        @s3_host_alias
      end

      def s3_url_options
        s3_url_options = @options[:s3_url_options] || {}
        s3_url_options = s3_url_options.call(instance) if s3_url_options.respond_to?(:call)
        s3_url_options
      end

      def bucket_name
        @bucket = @options[:bucket] || s3_credentials[:bucket]
        @bucket = @bucket.call(self) if @bucket.respond_to?(:call)
        @bucket or raise ArgumentError, "missing required :bucket option"
      end

      def s3_bucket
        @s3_bucket ||= s3_resource.bucket(bucket_name)
      end

      def s3_object(style_name = default_style)
        s3_bucket.object(path(style_name).sub(%r{\A/}, ''))
        #s3_interface.get_object(:bucket => bucket_name, :key => path(style_name).sub(%r{\A/},''))
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

      def set_permissions(permissions)
        permissions = { :default => permissions } unless permissions.respond_to?(:merge)
        permissions.merge :default => (permissions[:default] || 'public-read')
      end

      def set_storage_class(storage_class)
        storage_class = { :default => storage_class } unless storage_class.respond_to?(:merge)
        storage_class
      end

      def parse_credentials(creds)
        creds = creds.respond_to?('call') ? creds.call(self) : creds
        creds = find_credentials(creds).stringify_keys
        env   = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        if original_filename
          response = s3_client.get_object_acl bucket: bucket_name, key: path(style).sub(%r{\A/}, '')
          !!response
        else
          false
        end
      rescue Aws::S3::Errors::ServiceError => e
        false
      end

      def s3_permissions(style = default_style)
        s3_permissions = @s3_permissions[style] || @s3_permissions[:default]
        s3_permissions = s3_permissions.call(self, style) if s3_permissions.respond_to?(:call)
        s3_permissions
      end

      def s3_storage_class(style = default_style)
        @s3_storage_class[style] || @s3_storage_class[:default]
      end

      def s3_protocol(style = default_style, with_colon = false)
        protocol = @s3_protocol
        protocol = protocol.call(style, self) if protocol.respond_to?(:call)

        if with_colon && !protocol.empty?
          "#{protocol}:"
        else
          protocol.to_s
        end
      end

      def create_bucket
        s3_client.create_bucket bucket: bucket_name
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          retries = 0
          begin
            log("saving #{path(style)}")
            acl = @s3_permissions[style] || @s3_permissions[:default]
            acl = acl.call(self, style) if acl.respond_to?(:call)
            if acl
              acl = acl.to_s
              acl = acl.gsub('_', '-')
            end
            write_options = {
                :content_type => file.content_type,
                :acl          => acl
            }

            # add storage class for this style if defined
            storage_class = s3_storage_class(style)
            if storage_class
              storage_class = storage_class.to_s.downcase == 'reduced_redundancy' ? 'REDUCED_REDUNDANCY' : 'STANDARD'
              write_options.merge!(:storage_class => storage_class)
            end

            if @s3_server_side_encryption
              write_options.merge! @s3_server_side_encryption
            end

            style_specific_options = styles[style]

            if style_specific_options
              merge_s3_headers(style_specific_options[:s3_headers], @s3_headers, @s3_metadata) if style_specific_options[:s3_headers]
              @s3_metadata.merge!(style_specific_options[:s3_metadata]) if style_specific_options[:s3_metadata]
            end

            write_options[:metadata] = @s3_metadata unless @s3_metadata.empty?
            write_options.merge!(@s3_headers)

            s3_object(style).upload_file(file.to_tempfile, write_options)
            log("saved #{path(style)} to #{bucket_name} with #{write_options}")
          rescue Aws::S3::Errors::NoSuchBucket
            create_bucket
            retry
          rescue Aws::S3::Errors::BadDigest
            retries += 1
            if retries <= 5
              sleep(0.5)
              retry
            else
              raise
            end
          ensure
            begin
              file.rewind
            rescue IOError => e
              Rails.logger.warn("Error uploading filed. #{e.message}\n#{caller}")
            end
          end
        end

        after_flush_writes # allows attachment to clean up temp files

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            s3_client.delete_object(
                :bucket => bucket_name,
                :key    => path.sub(%r{\A/}, '')
            )
          rescue Aws::S3::Errors::NoSuchKey => e
            # Ignore this.
          rescue Aws::S3::Errors::NoSuchBucket => e
            # Ignore this.
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        log("copying #{path(style)} to local file #{local_dest_path}")
        ::File.open(local_dest_path, 'wb') do |local_file|
          s3_object(style).get do |chunk|
            local_file.write(chunk)
          end
        end
        true
      rescue Aws::S3::Errors::ServiceError => e
        warn("#{e} - cannot copy #{path(style)} to local file #{local_dest_path}")
        false
      end

      private

      def find_credentials creds
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

      def use_secure_protocol?(style_name)
        s3_protocol(style_name) == "https"
      end

      def merge_s3_headers(http_headers, s3_headers, s3_metadata)
        return if http_headers.nil?
        http_headers = http_headers.call(instance) if http_headers.respond_to?(:call)
        http_headers.inject({}) do |headers, (name, value)|
          case name.to_s
            when /\Ax-amz-meta-(.*)/i
              s3_metadata[$1.downcase] = value
            else
              s3_headers[name.to_s.downcase.sub(/\Ax-amz-/, '').tr("-", "_").to_sym] = value
          end
        end
      end
    end
  end
end