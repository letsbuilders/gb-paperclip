require 'paperclip/media_type_spoof_detector'

module Paperclip
  class MediaTypeSpoofDetector
    old_spoofed = instance_method(:spoofed?)

    define_method(:spoofed?) do
      if content_types_from_name.count > 0
        spoofed = old_spoofed.bind(self).()
        if defined? Rails
          if spoofed
            Rails.logger.fatal "MIME Spoofed file alert! file: '#{@name}' detected as '#{calculated_content_type}' but it should be: #{supplied_content_type}"
          elsif content_type_mismatch?
            Rails.logger.warn "MIME Spoofed probable file: '#{@name}' detected as '#{calculated_content_type}' but it should be: #{supplied_content_type}"
          end
        end
        spoofed
      else
        false
      end
    end

    def content_type_mismatch?
      supplied_content_type.present? && !content_types_from_name.collect(&:content_type).include?(calculated_content_type)
    end

    def spoofed_content_type
      calculated_content_type
    end
  end
end