require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")

module CPN
  class Net
    attr_reader :name, :states, :transitions, :arcs, :time

    def self.build(name, &block)
      cp = Net.new(name)
      cp.instance_eval &block
      cp
    end

    def initialize(name)
      @name = name
      @states, @transitions = {}, {}
      @arcs = []
      @time = 0
    end

    def state(name, init = nil, &block)
      state = State.new name
      state.initial = init unless init.nil?
      state.instance_eval &block if block_given?
      @states[name] = state
    end

    def transition(name, &block)
      t = Transition.new name
      t.instance_eval &block if block_given?
      @transitions[name] = t
    end

    def arc(from, to, expr = nil, &block)
      if @states.has_key?(from) && @transitions.has_key?(to)
        from, to = @states[from], @transitions[to]
      elsif @transitions.has_key?(from) && @states.has_key?(to)
        from, to = @transitions[from], @states[to]
      else
        raise "State or transition not found: #{from} --> #{to}"
        return
      end
      a = Arc.new(from, to)
      a.expr = expr unless expr.nil?
      a.instance_eval &block if block_given?
      from.outgoing << a
      to.incoming << a
      @arcs << a
    end

    def each_transition
      @transitions.values.each { |t| yield(t) }
    end

    def each_state
      @states.values.each { |s| yield(s) }
    end

    def arc_between(from, to)
      arcs.detect do |a|
        a.from.name == from && a.to.name == to
      end
    end

    def occur_next
      @transitions.values.select(&:enabled?).sample.occur(@time)
    end

    def advance_time
      @time += @transitions.values.map{ |t| t.min_distance_to_valid_combo(@time) }.min
    end

    def to_s
      "States #{@states.values.map(&:to_s).join(',')} \
       Transitions: #{@transitions.values.map(&:to_s).join(',')} \
       Arcs: #{@arcs.map(&:to_s).join(',')}"
    end

    def as_json
      {
        :states => @states.values.map { |s| s.as_json },
        :transitions => @transitions.values.map { |t| t.as_json },
        :arcs => @arcs.map { |a| a.as_json }
      }
    end

    def dump
      puts "Arcs of #{name}"
      @arcs.each do |a|
        puts a
      end
    end

  end

end

