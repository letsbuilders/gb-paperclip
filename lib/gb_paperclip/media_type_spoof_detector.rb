require 'paperclip/media_type_spoof_detector'

module Paperclip
  class MediaTypeSpoofDetector
    old_spoofed = instance_method(:spoofed?)

    define_method(:spoofed?) do
      if content_types_from_name.count > 0
        spoofed = old_spoofed.bind(self).()
        if defined? Rails
          Rails.logger.fatal "MIME Spoofed file alert! file: '#{filename_extension}' detected as '#{calculated_media_type}' but it should be: #{supplied_content_type}" if spoofed
        end
        spoofed
      else
        false
      end
    end
  end
end