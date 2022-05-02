# frozen_string_literal: true

require 'paperclip/has_attached_file'
module Paperclip
  class HasAttachedFile # :nodoc:
    def add_paperclip_callbacks
      @klass.send(
        :define_paperclip_callbacks,
        :post_process, :"#{@name}_post_process", :"#{@name}_validate", :async_post_process
      )
    end

    def add_active_record_callbacks # rubocop:disable Metrics/AbcSize
      name = @name
      create_save_callback
      @klass.send(:after_save) { send(name).send(:save) }
      @klass.send(:before_destroy) { send(name).send(:queue_all_for_delete) }
      @klass.send(:after_commit, on: :destroy) { send(name).send(:flush_deletes) }
      @klass.send(:after_commit, on: :update) { send(name).send(:is_saved!) }
      @klass.send(:after_commit, on: :create) { send(name).send(:is_saved!) }
      @klass.send(:after_rollback) { send(name).send(:is_saved!) }
      @klass.send(:around_save, :"#{@name}_around_save_callback")
    end

    def create_save_callback
      @klass.class_eval <<-END_CALLBACK, __FILE__, __LINE__ + 1
      def #{@name}_around_save_callback
        #{@name}.with_save_lock do
          #{@name}.is_saving!
          yield
          #{@name}.save
        end
      end
      END_CALLBACK
    end
  end
end
