module CPN
  class Arc
    attr_accessor :from, :to, :expr

    def initialize(from, to)
      @from, @to = from, to
    end

    # Return the binding for this arc with the given (input) token
    # e.g. token [1,2] and expression "a, b" returns an object o with o.a = 1 and o.b = 2 
    def token_binding(token)
      EvaluationContext.setup(expr, token)
    end

    def bindings_hash
      tokens.map { |token| token_binding(token).to_hash }
    end

    def to_s
      "#{@from.to_s} --#{(@expr && @expr.inspect) || '*'}--> #{@to.to_s}"
    end

    def tokens
      return [] unless @from.respond_to? :marking
      @from.marking
    end

    def remove_token(token)
      @from.remove_token(token)
    end

    def add_token(token)
      @to.add_token(token)
    end

  end

end

