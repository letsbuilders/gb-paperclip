require 'paperclip/io_adapters/abstract_adapter'
require 'zip'
module Paperclip
  class ZipEntryAdapter < AbstractAdapter
    # @param target [Zip::Entry]
    def initialize(target, options = {})
      @target                = target
      self.original_filename = @target.name.force_encoding('UTF-8').encode('UTF-16be', :invalid => :replace, :replace => '_').encode('UTF-8').split('/').pop
      @tempfile              = copy_to_tempfile(@target)
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
      destination
    end
  end
end

Paperclip.io_adapters.register Paperclip::ZipEntryAdapter do |target|
  Zip::Entry === target
end