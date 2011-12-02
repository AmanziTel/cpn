require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")

module CPN
  def self.build(name, &block)
    Builder.build_net(name, &block)
  end

  class Builder

    def initialize(page)
      @page = page
    end

    def self.build_net(name, &block)
      builder = Builder.new(Net.new(name))
      builder.instance_eval &block
      builder.result
    end

    def result
      @page
    end

    def page(name, &block)
      p = Page.new(name, @page)
      builder = Builder.new(p)
      builder.instance_eval &block

      @page.add_page(p)
    end

    def state(name, init = nil, &block)
      state = State.new name
      state.initial = init unless init.nil?
      state.instance_eval &block if block_given?
      @page.add_state(state)
    end

    def transition(name, &block)
      t = Transition.new name
      t.instance_eval &block if block_given?
      @page.add_transition(t)
    end

    def hs_transition(name, subpage_name)
    end

    def arc(from, to, expr = nil, &block)
      if @page.states.has_key?(from) && @page.transitions.has_key?(to)
        from, to = @page.states[from], @page.transitions[to]
      elsif @page.transitions.has_key?(from) && @page.states.has_key?(to)
        from, to = @page.transitions[from], @page.states[to]
      else
        raise "State or transition not found: #{from} --> #{to}"
        return
      end
      a = Arc.new(from, to)
      a.expr = expr unless expr.nil?
      a.instance_eval &block if block_given?
      from.outgoing << a
      to.incoming << a
      @page.add_arc(a)
    end

  end

  class Page
    attr_reader :name, :states, :transitions, :arcs, :pages, :superpage

    def initialize(name, superpage = nil)
      @name = name
      @superpage = superpage
      @states, @transitions = {}, {}
      @arcs = []
      @pages = []
    end

    def add_state(state)
      @states[state.name] = state
    end

    def add_transition(transition)
      @transitions[transition.name] = transition
    end

    def add_arc(arc)
      @arcs << arc
    end

    def add_page(page)
      @pages << page
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

  end

  class Net < Page
    attr_reader :time

    def initialize(name)
      super(name)
      @time = 0
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

