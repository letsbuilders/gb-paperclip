require 'paperclip'
module Paperclip
  module Validators
    class MediaTypeSpoofDetectionValidator
      def validate_each(record, attribute, value)
        adapter = Paperclip.io_adapters.for(value)
        if Paperclip::MediaTypeSpoofDetector.using(adapter, value.original_filename, value.content_type).spoofed?
          record.errors.add(attribute, :spoofed_media_type)
          move_to_quarantine adapter, value.original_filename
        end
      end

      def move_to_quarantine(adapter, original_filename)
        quarantine_path = "#{quarantine_directory}/#{Time.now.strftime('%Y%m%d%H%M%S%L')}_#{original_filename}"
        FileUtils.cp(adapter.path, quarantine_path)
      end

      def quarantine_directory
        path = 'tmp/quarantine'
        unless Dir.exists? path
          FileUtils.create 'tmp' unless Dir.exists? 'tmp'
          FileUtils.mkdir path
        end
        path
      end
    end
  end
end