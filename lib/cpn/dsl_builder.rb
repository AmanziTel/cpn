require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")
require File.expand_path("#{File.dirname __FILE__}/marking")

module CPN

  class DSLBuilder
    attr_accessor :resolver

    def initialize(page)
      @page = page
    end

    def self.build_net(name, &block)
      builder = DSLBuilder.new(Net.new(name))
      builder.instance_eval &block
      builder.result
    end

    def result
      @page
    end

    def page(name, &block)
      p = Page.new(name, @page)
      builder = DSLBuilder.new(p)
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

    def hs_transition(name, &block)
      subpage = Page.new(name, @page)
      subpage.instance_eval &block if block_given?
      @page.add_transition(subpage)
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
end

