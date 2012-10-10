require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")
require File.expand_path("#{File.dirname __FILE__}/marking")

module CPN

  # This class is the starting point for the Ruby DSL used to build
  # CPN models. The method CPN::DSLBuilder.build_net can be used to 
  # build a network (time based model) using the DSL methods page,
  # state, transition and arc.
  class DSLBuilder

    attr_reader :params
    def initialize(page, params = {})
      @page = page
      @page.builder = self
      @params = params
    end

    def to_s
      "Page[#{@page.name}]#{params.inspect}"
    end

    def self.build_net(name, path = nil, &block)
      net = Net.new(name)
      builder = DSLBuilder.new(net)
      if path = builder.clean_path(path)
        net.path = path
        builder.instance_eval(File.read(path))
      end
      builder.instance_eval &block if(block_given?)
      builder.result
    end

    def result
      @page
    end

    def clean_path(path)
      if path
        if path =~ /^\//
          "public/library/#{path}"
        elsif @page.path.nil?
          path
        else
          "#{File.dirname(@page.path)}/#{path}"
        end
      else
        nil
      end
    end

    def page(name, path = nil, cmd_params = {}, &block)
      name = name.to_s.intern
      p = Page.new(name, @page)
      builder = DSLBuilder.new(p)
      # Parent params pass to child, but overridden by command-line params (in child only)
      puts "Parent params: #{self.params.inspect}"
      puts "CMD params: #{cmd_params.inspect}"
      builder.params.merge!(self.params).merge!(cmd_params)
      puts "Child params: #{builder.params.inspect}"
      if path = clean_path(path)
        p.path = path
        puts "Loading page using builder: #{builder}"
        builder.instance_eval(File.read(path))
        puts "Child params after loading #{path}: #{builder.params.inspect}"
      end
      builder.instance_eval(&block) if(block_given?)
      puts "Child params after block: #{builder.params.inspect}"
      puts "Time increment: #{params[:event_time_incr]}"

      @page.add_page(p)
    end

    # Create multiple states, applying the same block to each in turn
    def states(*args, &block)
      args.each do |arg|
        [arg].flatten.each do |name|
          state name, &block
        end
      end
    end

    # Create a single state with the optional initialization and block
    def state(name, init = nil, &block)
      puts "Creating new state with name '#{name}' and initialization '#{init}'" if($debug)
      name = name.to_s.intern
      state = State.new name
      state.initial = init unless init.nil?
      state.instance_eval &block if block_given?
      state.initial.network = @page.net if(state.initial.respond_to? :network=)
      puts "Created state: #{state.inspect}" if($debug)
      @page.add_state(state)
    end

    def layout(map={})
      map.each do |name,p|
        name = name.to_s.intern
        if s = @page.states[name]
          s.properties[:x] = p[:x] if(p[:x])
          s.properties[:y] = p[:y] if(p[:y])
        elsif t = @page.transitions[name]
          t.properties[:x] = p[:x] if(p[:x])
          t.properties[:y] = p[:y] if(p[:y])
        else
          puts "State not found: #{name}"
        end
      end
    end

    # Create multiple transitions, applying the same block to each in turn
    def transitions(*args, &block)
      args.each do |arg|
        [arg].flatten.each do |name|
          transition name, &block
        end
      end
    end

    def transition(name, options = {}, &block)
      if options.is_a? String
        options = {:expr => options}
      end
      name = name.to_s.intern
      t = Transition.new name
      t.guard = options[:expr] unless options[:expr].nil?
      t.instance_eval &block if block_given?
      @page.add_transition(t)
    end

    def hs_transition(name, &block)
      name = name.to_s.intern
      subpage = Page.new(name, @page)
      subpage.builder = self
      subpage.instance_eval &block if block_given?
      @page.add_transition(subpage)
    end

    def make_arc(from, to, options = {}, &block)
      from = from.to_s.intern
      to = to.to_s.intern
      if @page.states.has_key?(from) && @page.transitions.has_key?(to)
        from, to = @page.states[from], @page.transitions[to]
      elsif @page.transitions.has_key?(from) && @page.states.has_key?(to)
        from, to = @page.transitions[from], @page.states[to]
      else
        raise "State or transition not found: #{from} --> #{to}"
        return
      end
      a = Arc.new(from, to)
      a.expr = options[:expr] unless options[:expr].nil?
      a.instance_eval &block if block_given?
      from.outgoing << a
      to.incoming << a
      @page.add_arc(a)
    end

    def arc(from, to, options = {}, &block)
      if options.is_a? String
        options = {:expr => options}
      end
      make_arc(from, to, options, &block)
      make_arc(to, from, options, &block) if(options[:bidirectional])
    end

  end
end

