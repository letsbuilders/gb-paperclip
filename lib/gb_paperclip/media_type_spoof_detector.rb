require 'paperclip/media_type_spoof_detector'

module Paperclip
  class MediaTypeSpoofDetector

    def spoofed?
      if has_name? && has_extension? && calculated_content_type_mismatch? && content_types_from_name.count > 0
        if media_type_mismatch? && mapping_override_mismatch?
          Paperclip.log("Content Type Spoof detected: Filename #{File.basename(@name)}, detected as #{calculated_content_type} but should be #{content_types_from_name.map(&:content_type).join(', ')}")
          true
        else
          Paperclip.log("Content Type Spoof probablity: Filename #{File.basename(@name)}, detected as #{calculated_content_type} but should be #{content_types_from_name.map(&:content_type).join(', ')}")
          false
        end
      else
        false
      end
    end

    def calculated_content_type_mismatch?
      !(calculated_content_type && content_types_from_name.include?(calculated_content_type))
    end

    def content_type_mismatch?
      supplied_content_type.present? && !content_types_from_name.collect(&:content_type).include?(calculated_content_type)
    end

    def spoofed_content_type
      calculated_content_type
    end
  end
end