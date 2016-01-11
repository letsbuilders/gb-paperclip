require 'paperclip/io_adapters/abstract_adapter'
module Paperclip
  class CopyAdapter < AbstractAdapter
    # @param target [Zip::Entry]
    def initialize(target)
      @target                = target
      self.original_filename = @target.original_filename
      @size                  = @target.size
      @tempfile              = copy_to_tempfile(@target)
      @target.rewind
      @content_type = @target.content_type
    end
  end
end

Paperclip.io_adapters.register Paperclip::CopyAdapter do |target|
  !!((target.is_a?(Class) ? target : target.class) < Paperclip::AbstractAdapter)
end