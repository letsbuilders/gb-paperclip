require 'paperclip/io_adapters/abstract_adapter'
require 'zip'
module Paperclip
  class ZipEntryAdapter < AbstractAdapter
    # @param target [Zip::Entry]
    def initialize(target)
      @target                = target
      @tempfile              = copy_to_tempfile(@target)
      self.original_filename = @target.name.force_encoding("UTF-8").split('/').pop
      @size                  = @target.size
      @content_type          = ContentTypeDetector.new(@tempfile.path).detect
    end

    private

    def copy_to_tempfile(src)
      src.get_input_stream do |is|
        buf = ''
        while (buf = is.sysread(::Zip::Decompressor::CHUNK_SIZE, buf))
          destination << buf
        end
      end
      destination.rewind
      puts destination.path
      destination
    end
  end
end

Paperclip.io_adapters.register Paperclip::ZipEntryAdapter do |target|
  Zip::Entry === target
end