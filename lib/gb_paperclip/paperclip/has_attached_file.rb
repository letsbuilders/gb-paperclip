require 'paperclip/has_attached_file'
module Paperclip
  class HasAttachedFile
    def add_paperclip_callbacks
      @klass.send(
          :define_paperclip_callbacks,
          :post_process, :"#{@name}_post_process", :async_post_process)
    end
  end
end
