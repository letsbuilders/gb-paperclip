require 'paperclip/attachment'
module Paperclip
  class Attachment
    module SaveExtension
      def initialize(*args)
        @processor_info_lock = Mutex.new
        @status_lock         = Mutex.new
        super
      end

      def save
        @status_lock.lock
        begin
          @is_saving        = true
          @queued_for_write = @queued_for_write.delete_if { |key, value| key != :original &&(value.nil? || value.kind_of?(Paperclip::NilAdapter)) }
        ensure
          @status_lock.unlock
        end
        super
        @status_lock.synchronize { @is_saving = false }
      end

      def is_saving?
        status_lock.synchronize { !!@is_saving }
      end

      def unlink_files(files)
        super files.compact
      end

      def post_process_style(name, style) #:nodoc:
        intermediate_files = []
        processing style
        begin
          raise RuntimeError.new("Style #{name} has no processors defined.") if style.processors.blank?

          @queued_for_write[name] = style.processors.inject(@queued_for_write[:original]) do |file, processor|
            file = Paperclip.processor(processor).make(file, style.processor_options, self)
            intermediate_files << file if file
            file
          end
          if @queued_for_write[name].nil?
            @queued_for_write.delete name
          else
            unadapted_file = @queued_for_write[name]
            @queued_for_write[name] = Paperclip.io_adapters.for(@queued_for_write[name])
            unadapted_file.close if unadapted_file.respond_to?(:close)
          end
        rescue Paperclip::Errors::NotIdentifiedByImageMagickError => e
          failed_processing style
          log("An error was received while processing: #{e.inspect}")
          (@errors[:processing] ||= []) << e.message if @options[:whiny]
        rescue Exception => e
          failed_processing style
          raise e
        ensure
          unlink_files(intermediate_files)
        end
      end

      def post_process(*style_args)
        super
      end
    end

    prepend SaveExtension

    def processing(style)
      style = get_style_name(style)
      begin
        @processor_info_lock.lock
        @processor_tracker ||= []
        if @processor_tracker.count == 0
          if is_dirty?
            @instance.processing = true
          else
            @instance.update_attribute :processing, true
          end
        end
        @processor_tracker << style
      ensure
        @processor_info_lock.unlock
      end
      @processor_tracker
    end

    def failed_processing(style)
      style = get_style_name(style)
      is_included = @processor_info_lock.synchronize { @processor_tracker.include? style }
      return unless is_included
      processor_info_lock.synchronize do
        @processor_tracker.delete style
      end
      save_processing_info
      @processed_styles
    end

    def finished_processing(style)
      style = get_style_name(style)
      is_included = processor_info_lock.synchronize { @processor_tracker.include? style }
      return unless is_included
      processor_info_lock.synchronize do
        @processor_tracker.delete style
        @processed_styles ||= []
        @processed_styles << style
      end
      save_processing_info
      @processed_styles
    end

    def is_dirty?
      status_lock.synchronize { @dirty }
    end

    private

    def dirty!
      status_lock.synchronize { @dirty = true }
    end

    # @return [Mutex]
    def processor_info_lock
      @processor_info_lock
    end

    # @return [Mutex]
    def status_lock
      @status_lock
    end

    def get_style_name(style)
      if style.is_a? Paperclip::Style
        style = style.name
      end
      style
    end

    def save_processing_info
      begin
        @processor_info_lock.lock
        @processed_styles ||= []
        if @processor_tracker.count == 0
          if is_dirty?
            @instance.processing = false
            @instance.processed_styles = @processed_styles
          else
            @instance.update_attributes processing: false, processed_styles: @processed_styles
          end
        end
      ensure
        @processor_info_lock.unlock
      end
    end
  end
end