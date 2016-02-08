module Paperclip
  module Storage
    module S3Improved
      begin
        require 'aws-sdk-v1'
      rescue LoadError => e
        e.message << " (You may need to install the aws-sdk gem)"
        raise e
      end unless defined?(AWS::Core)
      @@s3_instances = Hash.new
      @@s3_instances_v2 = Hash.new
      @@s3_lock      = Mutex.new

      def self.extended(base)
        base.extend Paperclip::Storage::S3
      end

      # @return [Hash]
      def s3_instances
        @@s3_instances
      end

      def s3_instances_v2
        @@s3_instances_v2
      end

      # @return [Mutex]
      def s3_lock
        @@s3_lock
      end

      def obtain_s3_instance_for(options)
        s3_lock.lock
        result = s3_instances[options] ||= AWS::S3.new(options)
        s3_lock.unlock
        result
      end

      def obtain_s3_v2_instance_for(options)
        s3_lock.lock
        result = s3_instances_v2[options] ||= Aws::S3::Client.new(options)
        s3_lock.unlock
        result
      end

      def s3_v2_interface
        @s3_interface_v2 ||= begin
          region = s3_host_name.split('.').first
          region = region.split('-')
          region.delete_if { |str| str == 's3' }
          region = region.join('-')
          config = { :region => region }

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

          obtain_s3_v2_instance_for(config.merge(@s3_options))
        end
      end

      def s3_v2_bucket
        @s3_bucket_v2 ||= s3_v2_interface.bucket(bucket_name)
      end

      # Generates authenticated url valid for given time with given name
      # @param time [Fixnum] seconds of link validity. Default 3600
      # @param file_name [String] name, how file with be saved.
      # @param style_name [String] style, for which url should be generated
      # @return [String]
      def expiring_url_with_name(time = 3600, file_name = nil, style_name = default_style)
        if path(style_name)
          base_options = { :expires => time, :secure => use_secure_protocol?(style_name) }
          if file_name
            base_options[:response_content_disposition] = "attachment;filename=\"#{file_name}\";"
          end
          s3_object(style_name).url_for(:read, base_options.merge(s3_url_options)).to_s
        else
          url(style_name)
        end
      end

      # @return [IO]
      def get_file_stream(style_name = default_style)
        s3_v2_interface.get_object(bucket: bucket_name, key: path(style_name).sub(%r{\A/}, '')).body
      end
    end
  end
end