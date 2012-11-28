require File.expand_path("#{File.dirname __FILE__}/node")

module CPN
  class State < Node
    attr_reader :marking
    attr_accessor :initial

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

    def remove_token(token, modify_initial = false)
      @marking.delete(token,false)
      @initial = @marking.as_json.join(', ') if(modify_initial)
    end

    def add_token(token, modify_initial = false)
      @marking << token
      @initial = @marking.as_json.join(', ') if(modify_initial)
    end

    def to_hash
      super.merge(
        :marking => marking.to_hash,
        :initial => initial
      )
    end

    def to_s
      s = "(#{@name})"
      s << "{#{@marking.as_json.join(',')}}" unless @marking.empty?
      s
    end

    def reset
      @marking.set(eval("[ #{@initial && @initial.to_s.gsub(/\@([\d\.]+)/,'.ready_at(\1)')} ]"))
    end

    def fuse_with(source_state)
      @marking.off
      source_state.marking.fuse_with(@marking)
      @marking = source_state.marking
      if @initial.nil?
        @initial = source_state.initial
      elsif source_state.initial.nil?
        source_state.initial = @initial
      end
      listen_to_marking
    end

    private

    def listen_to_marking
      @marking.on(:updated) do |source, op|
        @container.fire_state_changed(self, op) if @container
      end
    end

  end

end

