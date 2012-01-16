require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")
require File.expand_path("#{File.dirname __FILE__}/dsl_builder")
require File.expand_path("#{File.dirname __FILE__}/json_builder")

module CPN
  def self.build(name, &block)
    DSLBuilder.build_net(name, &block)
  end

  def self.build_json(name, json)
    JSONBuilder.build_net(name, json)
  end

  class Page < Node
    attr_reader :states, :transitions, :arcs, :pages, :superpage, :fuse_arcs, :prototype

    def initialize(name, superpage = nil)
      super(name)
      @superpage = superpage
      @states, @transitions = {}, {}
      @arcs = []
      @pages = {}
      @fuse_arcs = []
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

    def add_fuse_arc(state, hs_transition)
      @fuse_arcs << {
        :state => state,
        :hs_transition => hs_transition
      }
     end

    def add_page(page)
      @pages[page.name] = page
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

    def ready_transitions(at_time)
      enabled_transitions.select do |t|
        t.ready?(at_time)
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

    def fuse(superstate_name, substate_name)
      @states[substate_name] = @superpage.states[superstate_name]
      @superpage.add_fuse_arc(@states[substate_name], self)
    end

    def instanciate_from(prototype)
      @prototype = prototype
      prototype.each_state do |s|
        s = s.clone
        s.incoming, s.outgoing = [], []
        add_state(s) unless states[s.name]
      end
      prototype.each_transition do |t|
        t = t.clone
        t.incoming, t.outgoing = [], []
        add_transition(t)
      end
      prototype.arcs.each do |a|
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

    def min_distance_to_valid_combo(time_now)
      ds = @transitions.values.map{ |t| t.min_distance_to_valid_combo(time_now) }
      ds.compact.min
    end

    def to_s
      "Page: #{@name} " +
      "States #{@states.values.map(&:to_s).join(',')} " +
      "Transitions: #{@transitions.values.map(&:to_s).join(',')} " +
      "Arcs: #{@arcs.map(&:to_s).join(',')}"
    end

  end

  class Net < Page
    attr_reader :time

    def initialize(name)
      super(name)
      @time = 0
    end

    def occur_next
      ready = ready_transitions(@time)
      ready.sample.occur(@time) if ready.length > 0
    end

    def advance_time
      d = min_distance_to_valid_combo(@time)
      @time += d unless d.nil?
    end

    def dump
      puts "Arcs of #{name}"
      @arcs.each do |a|
        puts a
      end
    end

  end

end

