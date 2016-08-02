require 'paperclip/io_adapters/abstract_adapter'
require 'paperclip/storage/s3'
module Paperclip
  class AbstractAdapter
    def fingerprint
      @fingerprint ||= Digest::SHA512.file(path).to_s
    end
  end
end
