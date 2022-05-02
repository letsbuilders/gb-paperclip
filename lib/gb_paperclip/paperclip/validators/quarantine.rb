# frozen_string_literal: true

require 'kt-paperclip'

module Paperclip
  module Validators
    # Validator which is moving suspected spoofed files to quarantine folder
    class MediaTypeSpoofDetectionValidator
      def validate_each(record, attribute, value)
        adapter = Paperclip.io_adapters.for(value)
        return unless Paperclip::MediaTypeSpoofDetector
                      .using(adapter, value.original_filename, value.content_type)
                      .spoofed?

        record.errors.add(attribute, :spoofed_media_type)
        move_to_quarantine adapter, value.original_filename
      end

      def move_to_quarantine(adapter, original_filename)
        quarantine_path = "#{quarantine_directory}/#{Time.now.strftime('%Y%m%d%H%M%S%L')}_#{original_filename}"
        FileUtils.cp(adapter.path, quarantine_path)
      end

      def quarantine_directory
        path = 'tmp/quarantine'
        unless Dir.exist? path
          FileUtils.mkdir 'tmp' unless Dir.exist? 'tmp'
          FileUtils.mkdir path
        end
        path
      end
    end
  end
end
