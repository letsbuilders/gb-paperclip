module Paperclip
  module Storage
    class StorageProxy
      attr_accessor :options
      attr_accessor :queued_for_write
      attr_accessor :queued_for_delete

      def initialize(init_options, parent)
        @options = init_options
        @parent  = parent
        initialize_storage
      end

      def initialize_storage #:nodoc:
        storage_class_name = @options[:storage].to_s.downcase.camelize
        begin
          storage_module = Paperclip::Storage.const_get(storage_class_name)
        rescue NameError
          raise Errors::StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
        end
        self.extend(storage_module)
      end

      # Skip clean up of temp files.
      def after_flush_writes
        false
      end

      def method_missing(method, *args, &block)
        begin
          super
        rescue Exception
          @parent.send method, *args, &block
        end
      end
    end
  end
end