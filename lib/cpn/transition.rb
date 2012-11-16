require File.expand_path("#{File.dirname __FILE__}/node")
require File.expand_path("#{File.dirname __FILE__}/evaluation_context")

module CPN
  class CPN::Transition < Node
    attr_accessor :guard

    def enabled?
      valid_arc_token_combinations.length > 0
    end

    def ready?
      #$debug = true
      d = min_distance_to_valid_combo
      if $debug
        puts "Checking if transition '#{name}' is ready"
        puts "\tMin distance is #{d}"
        puts "\tready? => #{!d.nil? && d <= 0}"
      end
      !d.nil? && d <= 0
    end

    def occur
      at_time = @container.net.time
      atcs = ready_arc_token_combinations
      return nil if atcs.empty?
      arc_tokens = atcs.sample

      @container.fire_transition_fired(self, :before_fire)

      context = ArcTokenBinding.as_context(arc_tokens)
      states = []
      arc_tokens.each do |at|
        t = at.token
        at.arc.remove_token(t)
        t.ready_at(0) if t.respond_to? :ready_at
        t.on_transition(self) if t.respond_to? :on_transition
        states << at.arc.from
      end

      @outgoing.each do |arc|
        token = context.eval_output(arc.expr || "_token", at_time)
        arc.add_token(token) unless token.nil?
        states << arc.to
      end

      states.uniq.each do |s|
        s.marking.fire(:updated)
      end
      @container.fire_transition_fired(self, :after_fire)
      self
    end

    def min_distance_to_valid_combo
      #$debug = true
      at_time = @container.net.time
      puts "\tAt Time: #{at_time}" if($debug)
      distances = valid_arc_token_combinations.map do |arc_tokens|
        arc_tokens.map do |binding|
          puts "\t\tGetting distance for binding '#{binding}': #{binding.ready_distance(at_time)}" if($debug)
          binding.ready_distance(at_time)
        end.max
      end
      puts "\tDistances: #{distances.inspect}" if($debug)
      puts "\tMin distance: #{[ distances.min, 0].max if distances.length > 0}" if($debug)
      [ distances.min, 0].max if distances.length > 0
    end

    def to_hash
      super.merge(:guard => guard)
    end

    def to_s
      "|#{@name}|"
    end

   private

    def valid_arc_token_combinations
      ArcTokenBinding.product(@incoming).reject do |arc_tokens|
        context = ArcTokenBinding.as_context(arc_tokens)
        context.empty? || !context.eval_guard(@guard)
      end
    end

    # Return the list of enabled arc token combinations for which the ready distance is
    # the smallest.
    def ready_arc_token_combinations
      at_time = @container.net.time
      min_combos = []
      min_value = nil 

      valid_arc_token_combinations.each do |arc_tokens|
        readies = arc_tokens.map { |binding| binding.ready_distance(at_time) }
        if readies.all? { |t| t <= 0 }
          if min_value.nil? || readies.min < min_value
            min_combos = [ arc_tokens ]
            min_value = readies.min
          elsif readies.min == min_value
            min_combos << arc_tokens
          end
        end
      end
      min_combos
    end

  end

  class ArcTokenBinding
    attr_accessor :token, :arc, :binding

    def initialize(arc, token)
      @token = token
      @arc = arc
      @binding = arc.token_binding(token)
    end

    def ready_distance(at_time)
      #$debug = true
      if @token.respond_to?(:ready?)
        ans = (@token.ready? || at_time) - at_time
        if $debug
          puts "\t\tChecking if the token #{@token} is ready at time #{at_time}"
          puts "\t\tToken.ready?=#{@token.ready?} => distance=#{ans}"
        end
        ans
      else
        puts "\t\tThe token #{@token} has no time capability. Always ready!" if($debug)
        0
      end
    end

    def self.all_for_arc(arc)
      arc.tokens.map{ |t| ArcTokenBinding.new(arc, t) }
    end

    def to_hash
      {:token => @token.to_s, :arc => @arc.to_s, :binding => @binding.to_s}
    end

    # Return all combinations of arc, token for each arc
    # So, for arcs A1[t1, t2], A2[t3, t4], A3[t5, t6]
    # will produce
    # [ [ [A1 t1], [A2 t3], [A3 t5] ]
    #   [ [A1 t1], [A2 t3], [A3 t6] ]
    #   [ [A1 t1], [A2 t4], [A3 t5] ]
    # etc. (all combinations)
    def self.product(arcs)
      return [] if arcs.length == 0
      first_ats = all_for_arc(arcs.first)
      return [] if first_ats.length == 0
      return first_ats.map{|at| [ at ] }  if arcs.length == 1

      rest_cs = product(arcs[1..-1])

      result = []
      first_ats.each do |first_at|
        rest_cs.map do |cs|
          result << [ first_at ] + cs
        end
      end
      result
    end

    def self.as_context(arc_token_combinations)
      TransitionContext.by_merging(arc_token_combinations.map{|atc| atc.binding})
    end

  end
end

