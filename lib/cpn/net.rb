require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")

module CPN

  # A page is a sub-network. It is a valid CPN in its own right,
  # but might also be a component of a larger network.
  class Page < Node
    include CPN::Observable
    attr_reader :states, :transitions, :arcs, :pages, :fuse_arcs, :prototype
    attr_accessor :path, :builder

    event_source *CPN::ALL_EVENTS

    def initialize(name, container = nil)
      super(name)
      @container = container
      @states, @transitions = {}, {}
      @arcs = []
      @pages = {}
      @fuse_arcs = []
    end

    def net
      @container && @container.net
    end

    def h2h(h)
      a2h(h.to_a.map{|v| v[1]},true)
    end

    def to_hash
      super.merge(
        :states => h2h(states),
        :transitions => h2h(transitions)
      )
    end

    def fire_transition_fired(t, op)
      fire(op, t)
      container.fire_transition_fired(t, op) if container
    end

    def fire_state_changed(s, op)
      fire(:state_changed, s)
      container.fire_state_changed(s, :state_changed) if container
    end

    def add_state(state)
      @states[state.name] = state
      state.container = self
      state
    end

    def add_transition(transition)
      @transitions[transition.name] = transition
      transition.container = self
      transition
    end

    def add_arc(arc)
      @arcs << arc
      arc
    end

    def add_fuse_arc(state, hs_transition, direction = :out)
      @fuse_arcs << {
        :state => state,
        :hs_transition => hs_transition,
        :direction => direction
      }
      @fuse_arcs[-1]
    end

    def add_page(page)
      @pages[page.name] = page
      raise "Page does not belong here" unless page.container == self
      page
    end

    def each_transition
      @transitions.values.each { |t| yield(t) }
    end

    def enabled_transitions
      enabled = []
      @transitions.values.each do |t|
        if t.respond_to? :enabled_transitions
          enabled += t.enabled_transitions
        else
          enabled << t if t.enabled?
        end
      end
      enabled
    end

    def ready_transitions
      enabled_transitions.select do |t|
        t.ready?
      end
    end

    def each_state
      @states.values.each { |s| yield(s) }
    end

    def node(name)
      @states[name] || @transitions[name]
    end

    def arc_between(from, to)
      arcs.detect do |a|
        a.from.name == from && a.to.name == to
      end
    end

    def fuse(*states)
      names = states.map do |state|
        state.respond_to?(:name) && state.name || state.to_s.intern
      end
      names[1] ||= names[0]
      superstate = @container.states[names[0]] ||= builder.state(names[0])
      raise "Superstate '#{names[0]}' not found" unless superstate
      substate = @states[names[1]]
      raise "Substate '#{names[1]}' not found" unless substate
      substate.fuse_with(superstate)
      outgoing = transitions.values.detect do |t|
        arc_between(t.name,substate.name)
      end
      @container.add_fuse_arc(superstate, self, outgoing ? :out : :in)
    end

    def prototype=(prototype)
      raise "No prototype given" unless prototype
      if prototype.kind_of? Page
        @prototype = prototype
      elsif prototype.kind_of? Hash
        @prototype = builder.page prototype[:name], prototype[:path]
      else
        @prototype = @container.pages[prototype.to_s.intern]
      end
      raise "Unable to resolve prototype '#{prototype}'" unless @prototype
      @prototype.each_state do |s|
        s = s.clone
        s.incoming, s.outgoing = [], []
        add_state(s) unless states[s.name]
      end
      @prototype.each_transition do |t|
        t = t.clone
        t.incoming, t.outgoing = [], []
        add_transition(t)
      end
      @prototype.arcs.each do |a|
        from, to = node(a.from.name), node(a.to.name)
        arc = Arc.new(from, to)
        arc.expr = a.expr
        from.outgoing << arc
        to.incoming << arc
        add_arc(arc)
      end
      # TODO: Add the pages of the prototype
      self
    end

    def min_distance_to_valid_combo
      ds = @transitions.values.map{ |t| t.min_distance_to_valid_combo }
      ds.compact.min
    end

    def reset
      each_transition do |t|
        t.reset if t.respond_to? :reset
      end
      each_state do |s|
        s.reset
      end
    end

    def to_s
      "Page: #{@name} " +
      "States #{@states.values.map(&:to_s).join(',')} " +
      "Transitions: #{@transitions.values.map(&:to_s).join(',')} " +
      "Arcs: #{@arcs.map(&:to_s).join(',')}"
    end

  end

  # A Net is a CPN::Page that includes the concept of time. This is used for
  # CPN's that involve time based simulations. This could include modeling the
  # flow of resources across a physical or virtual network, or modeling the
  # time-ordered logic of a contingency plan, or decision sequence.
  class Net < Page
    attr_reader :time

    def initialize(name)
      super(name)
      @time = 0
    end

    def net
      self
    end

    def occur_next
      ready = ready_transitions
      if ready.length > 0
        t = ready.sample
        t.occur
      end
    end

    def occur_advancing_time
      advance_time if ready_transitions.empty?
      occur_next
    end

    def occur_all_ready
      while !ready_transitions.empty?
        occur_next
      end
    end

    def occur_by_time(steps = 1)
      steps.times do |step|
        occur_all_ready
        @time += 1
        fire(:tick)
      end
    end

    def finished?
      min_distance_to_valid_combo.nil?
    end

    def advance_time
      d = min_distance_to_valid_combo
      @time += d unless d.nil?

      fire(:tick)
      @time
    end

    def reset
      super
      @time = 0
      fire(:tick)
    end

    def dump
      puts "Arcs of #{name}"
      @arcs.each do |a|
        puts a
      end
    end

  end

end

