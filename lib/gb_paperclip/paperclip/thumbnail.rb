require 'paperclip/thumbnail'
module Paperclip
  class Thumbnail
    module SaveExtension
      def initialize(file, options = {}, attachment = nil)
        super
        @style = options[:style]
      end

      def make
        result = super
        @attachment.finished_processing @style if @attachment && @style
        result
      end
    end

    prepend SaveExtension
  end
end