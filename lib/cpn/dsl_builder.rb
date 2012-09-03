require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")
require File.expand_path("#{File.dirname __FILE__}/marking")

module CPN

  # This class is the starting point for the Ruby DSL used to build
  # CPN models. The method CPN::DSLBuilder.build_net can be used to 
  # build a network (time based model) using the DSL methods page,
  # state, transition and arc.
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

    def page(name, path = nil, &block)
      p = Page.new(name, @page)
      builder = DSLBuilder.new(p)
      if path
        path =
          (path =~ /^\// || @page.path.nil?) ?
          "public/library/#{path}" :
          "#{File.dirname(@page.path)}/#{path}"
        p.path = path
        builder.instance_eval(File.read(path))
      end
      builder.instance_eval(&block) if(block_given?)

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

