module CPN
  class State < Node
    attr_accessor :marking

    def initialize(name)
      super
      @marking = []
    end

    def initial=(init_expr)
      @initial = init_expr
      reset
    end

    def empty?
      @marking.empty?
    end

    def remove_token(token)
      i = @marking.index(token)
      raise "Unknown token #{token}" if i.nil?
      @marking.delete_at(i)

      changed
      notify_observers(self, :token_removed, @marking)
    end

    def add_token(token)
      @marking << token

      changed
      notify_observers(self, :token_added, @marking)
    end

    def to_s
      s = "(#{@name})"
      s << "{#{@marking.map(&:inspect).join(',')}}" unless @marking.empty?
      s
    end

    def as_json
      hash = {
        :name => name,
        :marking => marking.map(&:inspect)
      }
      hash[:description] = description unless description.nil?
      hash[:x] = x unless x.nil?
      hash[:y] = y unless y.nil?
      hash
    end

    def reset
      @marking = eval("[ #{@initial} ]")
    end

  end
end
