module CPN
  # TODO: Wrap the evals here in a sandboxed environment
  class EvaluationContext

    # An incoming arc token binding sets up the context for evaluation
    # An expr would typically have the form @x, @y and a token an array with two items.
    def self.setup(expr, token)
      ctx = EvaluationContext.new
      expr = "token" if expr.nil? || expr.length == 0
      ctx.set(expr, token)
      ctx
    end

    # What variable names (symbols) are active in the current context?
    def var_names
      @var_names ||= eval "local_variables", get_binding
    end

    def variable_get(name)
      locals[name.to_sym]
    end

    def set(lvalue, value)
      # "Set the lvalue to nil if false" is done to define the variables in the lvalue as local
      # variables visible from outside the lambda block. Otherwise they are defined by the lambda
      # as local to that.
      # The lambda is used so that values that can't easily be represented as text (e.g. objects)
      # can be assigned to also. If we restrict values (tokens) to be JSON data this is not needed.
      (eval("#{lvalue} = nil if false ; lambda { |v| #{lvalue} = v }", get_binding)).call(value)
      @var_names = nil
      @locals = nil
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

    # Use a local method scope as the binding
    def get_binding
      @binding ||= binding
    end

    private

    # Return a hash of visible variable names to their values in the current context
    def locals
      @locals ||= var_names.inject({}) { |memo, v| memo.merge!({ v => eval(v.to_s, get_binding) }) }
    end

  end

  class TransitionContext < EvaluationContext

    def self.by_merging(evaluation_contexts)
      evaluation_contexts.inject(TransitionContext.new) do |context, next_context|
        return [] unless context.compatible?(next_context)
        context.merge! next_context
      end
    end

    def merge!(other)
      raise "Can't merge incompatible contexts" and return unless compatible?(other)
      other.var_names.each do |name|
        set(name, other.variable_get(name))
      end
      self
    end

    def compatible?(other)
      (var_names & other.var_names).all? do |name|
        variable_get(name) == other.variable_get(name)
      end
    end

    def eval_output(expr)
      return eval(expr, get_binding) unless expr.nil? || expr.length == 0
      variable_get(var_names.first) if var_names.size == 1
    end

    def eval_guard(expr)
      return eval(expr, get_binding) unless expr.nil? || expr.length == 0
      true
    end

  end

end

