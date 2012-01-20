require File.expand_path("#{File.dirname __FILE__}/state")

module CPN
  class State < Node
    attr_accessor :marking

    def initialize(name)
      super
      @marking = CPN::Marking.new
      @marking.add_observer(self)
    end

    def initial=(init_expr)
      @initial = init_expr
      reset
    end

    def empty?
      @marking.empty?
    end

    def remove_token(token)
      @marking.delete(token)
    end

    def add_token(token)
      @marking << token
    end

    def update(source, op)
      changed
      notify_observers(self, op)
      @container.fire_state_changed(self, op) if @container
    end

    def to_s
      s = "(#{@name})"
      s << "{#{@marking.map(&:inspect).join(',')}}" unless @marking.empty?
      s
    end

    def reset
      @marking.set(eval("[ #{@initial} ]"))
    end

    def fuse_with(source_state)
      @marking.delete_observer(self)
      @marking = source_state.marking
      @marking.add_observer(self)
    end
  end
end
