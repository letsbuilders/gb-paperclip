require 'active_model/validations/presence'
require 'gb_paperclip/media_type_spoof_detector'
module Paperclip
  module Validators
    class AttachmentSpoofWarningValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        adapter  = Paperclip.io_adapters.for(value)
        detector = Paperclip::MediaTypeSpoofDetector.using(adapter, value.original_filename, value.content_type)
        if content_type_mismatch?(detector)
          record.send "#{attribute}_spoof_warning=", true
          record.send "#{attribute}_spoof_content_type=", detector.spoofed_content_type
        end
        adapter.close unless adapter.nil?
      end

      def self.helper_method_name
        :validates_spoof_warning
      end

      private

      def content_type_mismatch?(detector)
        if detector.is_a? Hash
          detector[:content_type_mismatch?]
        else
          detector.content_type_mismatch?
        end
      end
    end

    module HelperMethods
      # Places ActiveModel validations on the presence of a file.
      # Options:
      # * +if+: A lambda or name of an instance method. Validation will only
      #   be run if this lambda or method returns true.
      # * +unless+: Same as +if+ but validates if lambda or method returns false.
      def validates_spoof_warning(*attr_names)
        options = _merge_attributes(attr_names)
        validates_with AttachmentSpoofWarningValidator, options.dup
        validate_before_processing AttachmentSpoofWarningValidator, options.dup
      end
    end
  end
end