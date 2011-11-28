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

      context = EvaluationContext.merged(arc_tokens.map{|at| at.binding})
      arc_tokens.each do |at|
        at.arc.remove_token(at.token)
      end

      @outgoing.each do |arc|
        token = context.eval_output(arc.expr)
        arc.add_token(token) unless token.nil?
      end

      changed
      notify_observers(self, :end, enabled?)
    end

    def valid_arc_token_combinations
      atcs = ArcTokenCombination.all(@incoming)
      atcs.reject do |arc_tokens|
        context = EvaluationContext.merged(arc_tokens.map{|at| at.binding})
        context.empty? || !context.eval_guard(@guard)
      end
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

  class ArcTokenCombination
    attr_accessor :token, :arc, :binding

    def initialize(arc, token)
      @token = token
      @arc = arc
      @binding = arc.token_binding(token)
    end

    # Return all combinations of arc, token for each arc
    # So, for arcs A1[t1, t2], A2[t3, t4], A3[t5, t6]
    # will produce
    # [ [ [A1 t1], [A2 t3], [A3 t5] ]
    #   [ [A1 t1], [A2 t3], [A3 t6] ]
    #   [ [A1 t1], [A2 t4], [A3 t5] ]
    # etc. (all combinations)
    def self.all(arcs)
      return [] if arcs.length == 0
      first_ats = arcs.first.tokens.map { |t| ArcTokenCombination.new(arcs.first, t) }
      return [] if first_ats.length == 0
      return first_ats.map{|at| [ at ] }  if arcs.length == 1

      rest_cs = all(arcs[1..-1])

      result = []
      first_ats.each do |first_at| 
        rest_cs.map do |cs| 
          result << [ first_at ] + cs
        end
      end
      result
    end

  end
end

