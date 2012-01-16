require "json"

require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")

module CPN

  class JSONBuilder

    def initialize(page)
      @page = page
    end

    def self.build_net(name, json)
      builder = JSONBuilder.new(Net.new(name))
      source = JSON.parse(json)
      source = source["network"]
      return builder.result if source.nil?
      builder.metadata(source["metadata"]) if source["metadata"]
      builder.states(source["states"]) if source["states"]
      builder.transitions(source["transitions"]) if source["transitions"]
      builder.arcs(source["arcs"]) if source["arcs"]
      builder.result
    end

    def result
      @page
    end

    def states(source)
      source.each { |s| state s }
    end

    def transitions(source)
      source.each { |t| transition t }
    end

    def arcs(source)
      source.each { |a| arc a }
    end

    def state(source)
      state = State.new source["name"]
      state.initial = source["marking"]
      state.properties = source["properties"]
      @page.add_state(state)
    end

    def transition(source)
      t = Transition.new source["name"]
      t.guard = source["guard"]
      t.properties = source["properties"]
      @page.add_transition(t)
    end

    def arc(source)
      from, to = source["from"], source["to"]
      if @page.states.has_key?(from) && @page.transitions.has_key?(to)
        from, to = @page.states[from], @page.transitions[to]
      elsif @page.transitions.has_key?(from) && @page.states.has_key?(to)
        from, to = @page.transitions[from], @page.states[to]
      else
        raise "State or transition not found: #{from} --> #{to}"
        return
      end
      a = Arc.new(from, to)
      a.expr = source["expr"]
      from.outgoing << a
      to.incoming << a
      @page.add_arc(a)
    end

  end
end

