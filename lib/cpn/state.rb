require File.expand_path("#{File.dirname __FILE__}/node")

module CPN
  class State < Node
    attr_accessor :marking

    def initialize(name)
      super
      @marking = CPN::Marking.new
      listen_to_marking
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

    def to_s
      s = "(#{@name})"
      s << "{#{@marking.map(&:inspect).join(',')}}" unless @marking.empty?
      s
    end

    def reset
      @marking.set(eval("[ #{@initial} ]"))
    end

    def fuse_with(source_state)
      @marking.remove_listeners
      @marking = source_state.marking
      listen_to_marking
    end

    private

    def listen_to_marking
      @marking.on([ :token_added, :token_removed ]) do |source, op|
        @container.fire_state_changed(self, op) if @container
      end
    end
  end
end
