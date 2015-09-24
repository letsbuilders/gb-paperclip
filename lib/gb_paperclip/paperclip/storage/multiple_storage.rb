module Paperclip
  module Storage
    module MultipleStorage
      def self.extended base
        base.instance_eval do

          main_store_options           = @options.clone
          main_store_options[:storage] = main_store_options[:stores][:main][:storage]
          main_store_options           = main_store_options.merge(main_store_options[:stores][:main])
          main_store_options.delete :stores

          @main_store               = Paperclip::Storage::StorageProxy.new main_store_options, self
          @options[:url]            = @main_store.options[:url]
          @additional_stores        = []
          additional_stores_options = @options.clone
          (additional_stores_options[:stores][:additional] || []).each do |store_option|
            additional_store_options           = @options.clone
            additional_store_options[:storage] = store_option[:storage]
            @additional_stores << Paperclip::Storage::StorageProxy.new(additional_store_options.merge(store_option), self)
          end
          @backup_sync = @options[:backup_form] == :sync
          @backup_stores         = []
          backups_stores_options = @options.clone
          (backups_stores_options[:stores][:backups] || []).each do |store_option|
            backup_store_options           = @options.clone
            backup_store_options[:storage] = store_option[:storage]
            @backup_stores << Paperclip::Storage::StorageProxy.new(backup_store_options.merge(store_option), self)
          end
        end
      end

      def main_store
        @main_store
      end

      def additional_stores
        @additional_stores
      end

      def backup_stores
        @backup_stores
      end

      def exists?(style_name = default_style)
        @main_store.exists?(style_name)
      end

      def flush_writes #:nodoc:
        threads          =[]
        critical_threads = []
        @backup_stores.each do |store|
          store.queued_for_write  = @queued_for_write.clone.delete_if { |style, _| style != :original }
          if @backup_sync
            store.flush_writes
          else
            (thr = Thread.new do
              begin
                ActiveRecord::Base.connection_pool.with_connection do
                  store.flush_writes
                end
              rescue Exception => e
                Thread.current[:error] = e
              ensure
                ActiveRecord::Base.clear_active_connections!
              end
            end).abort_on_exception = false
            threads << thr
            critical_threads << thr
          end
        end
        @additional_stores.each do |store|
          store.queued_for_write = @queued_for_write.clone
          (thr = Thread.new do
            begin
              ActiveRecord::Base.connection_pool.with_connection do
                store.flush_writes
              end
            ensure
              ActiveRecord::Base.clear_active_connections!
            end
          end).abort_on_exception = false
          threads << thr
        end
        @main_store.queued_for_write = @queued_for_write.clone
        @main_store.flush_writes
        critical_threads.delete_if { |thread| !thread.alive? && !thread[:error] }
        while critical_threads.any?
          error = critical_threads.select { |thread| thread[:error] }.first
          raise error if error
          sleep 0.1
          critical_threads.delete_if { |thread| !thread.alive? && !thread[:error] }
        end
        threads.delete_if { |thread| !thread.alive? }
        if threads.any?
          Thread.new do
            while threads.any?
              sleep 0.1
              threads.delete_if { |thread| !thread.alive? }
            end
            ActiveRecord::Base.connection_pool.with_connection do
              after_flush_writes
            end
            ActiveRecord::Base.clear_active_connections!
          end
        else
          after_flush_writes
        end

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @additional_stores.each do |store|
          store.queued_for_delete = @queued_for_delete.clone
          Thread.new do
            begin
              ActiveRecord::Base.connection_pool.with_connection do
                store.flush_deletes
              end
            ensure
              ActiveRecord::Base.clear_active_connections!
            end
          end
        end

        @main_store.queued_for_delete = @queued_for_delete.clone
        @main_store.flush_deletes

        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        result = @main_store.copy_to_local_file(style, local_dest_path)
        return result if result
        @additional_stores.each do |store|
          begin
            result = store.copy_to_local_file(style, local_dest_path)
          rescue Exception => e
            Rails.logger.warn("Cannot copy file form additional storage. #{e.message}")
            result = nil
          end
          return result if result
        end
        @backup_stores.each do |store|
          begin
            result = store.copy_to_local_file(style, local_dest_path)
          rescue Exception => e
            Rails.logger.warn("Cannot copy file form backup storage. #{e.message}")
            result = nil
          end
          return result if result
        end
        false
      end

      def method_missing(method, *args, &block)
        if @main_store.respond_to? method
          @main_store.send(method, *args, &block)
        else
          super
        end
      end
    end
  end
end
