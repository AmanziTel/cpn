require 'observer'

module CPN
  module Observable

    def on(ops, &block)
      ops = [ ops ] unless ops.respond_to?(:each)
      @observers ||= {}
      ops.each do |op|
        raise "Unsupported op #{op}" unless observable_event_type?(op)
        @observers[op] ||= []
        @observers[op] << block
      end
    end

    def remove_listener(op, &block)
      @observers && @observers[op] && @observers[op].delete(block)
    end

    def remove_listeners
      @observers = {}
    end

    def fire(op, context = self)
      raise "Unsupported op #{op}" unless observable_event_type?(op)
      @observers && @observers[op] && @observers[op].each do |block|
        block.call(context, op)
      end
    end

    def self.included(base)
      def base.event_source(*event_types)
        define_method :observable_event_type? do |type|
          event_types.empty? || event_types.include?(type)
        end
      end
    end

  end
end
