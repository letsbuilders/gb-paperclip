require 'gb_paperclip/paperclip/io_adapters/copy_adapter'
module Paperclip
  module Storage
    class StorageProxy
      attr_accessor :options
      attr_reader :queued_for_write
      attr_accessor :queued_for_delete

      def initialize(init_options, parent)
        @options = init_options
        @parent  = parent
        initialize_storage
      end

      def initialize_storage #:nodoc:
        storage_class_name = @options[:storage].to_s.downcase.camelize
        @storage_name      = storage_class_name
        begin
          storage_module = Paperclip::Storage.const_get(storage_class_name)
        rescue NameError
          raise Errors::StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
        end
        self.extend(storage_module)
      end

      def queued_for_write=(queue)
        @queued_for_write = Hash.new
        queue.each do |key, file|
          @queued_for_write[key] = Paperclip::CopyAdapter.new(file)
        end
        @queued_for_write
      end

      # Skip clean up of temp files.
      def after_flush_writes
        unlink_files @queued_for_write.values
        false
      end

      def unlink_files(files)
        Array(files).each do |file|
          file.close unless file.closed?
          file.unlink if file.respond_to?(:unlink) && file.path.present? && File.exist?(file.path)
        end
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