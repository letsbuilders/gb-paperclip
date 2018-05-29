module VersionHelper
  def active_support_version
    ActiveSupport::VERSION::STRING
  end

  def ruby_version
    RUBY_VERSION
  end
end

require 'concurrent'
module GBDispatch
  class Runner
    class << self
      def _run_block(block, options)
        begin
          name = options[:name]
          Thread.current[:name] ||= name if name
          result = block.call
          result
        rescue Exception => e
          if defined?(Raven)
            Raven.tags_context :gb_dispacth => true
            Raven.extra_context :dispatch_queue => name
            Raven.capture_exception(e)
          end
          GBDispatch.logger.error "Failed execution of queue #{name} with error #{e.message}"
          e.backtrace.each { |m| GBDispatch.logger.error m }
          raise e
        end
      end
    end
  end
end
