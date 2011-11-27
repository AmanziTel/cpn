module CPN
  # TODO: Wrap the evals here in a sandboxed environment
  class EvaluationContext

    def get_binding
      @binding ||= binding
    end

    # An incoming arc token binding sets up the context for evaluation
    # An expr would typically have the form @x, @y and a token an array with two items.
    def self.setup(expr, token)
      ctx = EvaluationContext.new
      expr = "token" if expr.nil? || expr.length == 0
      ctx.set(expr, token)
      ctx
    end

    def eval_output(expr)
      return eval(expr, get_binding) unless expr.nil? || expr.length == 0
      variable_get(var_names.first) if var_names.size == 1
    end

    def eval_guard(expr)
      return eval(expr, get_binding) unless expr.nil? || expr.length == 0
      true
    end

    def var_names
      @var_names ||= eval "local_variables", get_binding
    end

    def locals
      @locals ||= var_names.inject({}) { |memo, v| memo.merge!({ v => eval(v.to_s, get_binding) }) }
    end

    def variable_get(name)
      locals[name.to_sym]
    end

    def set(lvalue, value)
      (eval("#{lvalue} = nil if false ; lambda { |v| #{lvalue} = v }", get_binding)).call(value)
      @var_names = nil
      @locals = nil
    end

    def compatible?(other)
      (var_names & other.var_names).all? do |name|
        variable_get(name) == other.variable_get(name)
      end
    end

    def merge!(other)
      raise "Can't merge incompatible contexts" and return unless compatible?(other)
      other.var_names.each do |name|
        set(name, other.variable_get(name))
      end
      self
    end

    def empty?
      var_names.empty?
    end

    def to_hash
      locals
    end

    def to_s
      to_hash.inspect
    end

  end

end

