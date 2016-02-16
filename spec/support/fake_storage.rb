module Paperclip
  module Storage
    module Fake
      def self.extended base
      end

      def exists=(value)
        @exists = value
      end

      def exists?(*args)
        @exists.nil? ? true : @exists
      end

      def sleep_time=(value)
        @sleep = value
      end

      def sleep_time
        @sleep ||= 0.01
      end

      def saved
        @saved ||= Hash.new
      end

      def deleted
        @deleted ||= []
      end

      def save_thread
        @save_thread
      end

      def delete_thread
        @delete_thread
      end

      def flush_writes
        @save_thread = Thread.current
        @queued_for_write.each do |style_name, path|
          sleep(sleep_time) unless sleep_time == 0
          saved[style_name] = path
          log("fake save #{style_name} to #{path}")
        end
        after_flush_writes # allows attachment to clean up temp files
        @queued_for_write = {}
      end

      def flush_deletes
        @delete_thread = Thread.current
        @queued_for_delete.each do |path|
          sleep(sleep_time) unless sleep_time == 0
          deleted << path
          log "deleted #{path}"
        end
        @queued_for_delete = []
      end

      def options_foo
        @options[:foo]
      end

      def options_bar
        @options[:bar]
      end
    end
  end

  class FakeProcessor < Processor

    def make
      raise self.class.raise_error if self.class.raise_error
      self.class.return_nil ? nil : @file
    end

    class << self
      attr_accessor :return_nil, :raise_error
    end
  end
end
