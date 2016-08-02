require 'paperclip/storage/s3'
module Paperclip
  class AbstractAdapter
    # @return [Tempfile]
    def to_tempfile
      @tempfile
    end
  end

  module Storage
    module S3

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

      # @return [::Aws::S3::Client]
      def s3_client
        s3_interface.client
      end

      # @return [IO]
      def get_file_stream(style_name = default_style)
        s3_client.get_object(bucket: bucket_name, key: style_name_as_path(style_name)).body
      end

      def s3_storage_class(style = default_style)
        @s3_storage_class[style] || @s3_storage_class[:default] || 'STANDARD'
      end
    end
  end
end