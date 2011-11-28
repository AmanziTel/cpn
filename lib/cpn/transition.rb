require File.expand_path("#{File.dirname __FILE__}/node")
require File.expand_path("#{File.dirname __FILE__}/evaluation_context")

module CPN
  class Transition < Node
    attr_accessor :guard

    def enabled?
      valid_arc_token_combinations.length > 0
    end

    def occur
      atcs = valid_arc_token_combinations
      return false if atcs.empty?
      arc_tokens = atcs.sample

      changed
      notify_observers(self, :start, true)

      context = binding_for(arc_tokens)
      arc_tokens.each do |at|
        arc, token = at[:arc], at[:token]
        arc.remove_token(token)
      end

      @outgoing.each do |arc|
        token = context.eval_output(arc.expr)
        arc.add_token(token) unless token.nil?
      end

      changed
      notify_observers(self, :end, enabled?)
    end

    def valid_arc_token_combinations
      atcs = arc_token_combinations(@incoming)
      atcs.reject do |arc_tokens|
        context = binding_for(arc_tokens)
        context.empty? || !context.eval_guard(@guard)
      end
    end

    def binding_for(arc_tokens)
      arc_tokens.inject(EvaluationContext.new) do |binding, arc_token|
        next_binding = arc_token[:binding]
        return [] unless binding.compatible?(next_binding)
        binding.merge! next_binding
      end
    end

    # Return all combinations of arc, token for each arc
    # So, for arcs A1[t1, t2], A2[t3, t4], A3[t5, t6]
    # will produce
    # [ [ [A1 t1], [A2 t3], [A3 t5] ]
    #   [ [A1 t1], [A2 t3], [A3 t6] ]
    #   [ [A1 t1], [A2 t4], [A3 t5] ]
    # etc. (all combinations)

    def arc_token_combinations(arcs)
      return [] if arcs.length == 0
      first_ats = arcs.first.tokens.map do |t|
        { :token => t, :arc => arcs.first, :binding => arcs.first.token_binding(t) }
      end
      return [] if first_ats.length == 0
      return first_ats.map{|at| [ at ] }  if arcs.length == 1

      rest_cs = arc_token_combinations(arcs[1..-1])

      result = []
      first_ats.each do |first_at| 
        rest_cs.map do |cs| 
          result << [ first_at ] + cs
        end
      end
      result
    end

    def to_s
      "|#{@name}|"
    end

    def as_json
      hash = {
        :name => name,
        :enabled => enabled?,
        :guard => guard
      }
      hash[:x] = x unless x.nil?
      hash[:y] = y unless y.nil?
      hash
    end

  end
end

