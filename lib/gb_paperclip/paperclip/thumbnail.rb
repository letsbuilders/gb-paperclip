require 'paperclip/thumbnail'
module Paperclip
  class Thumbnail
    module SaveExtension
      def make
        result = super
        @attachment.finished_processing @style if @attachment && @style
        result
      end
    end

    prepend SaveExtension
  end
end