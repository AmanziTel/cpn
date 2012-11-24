require File.expand_path("#{File.dirname __FILE__}/transition")
require File.expand_path("#{File.dirname __FILE__}/state")
require File.expand_path("#{File.dirname __FILE__}/marking")

module CPN

  # This class is the starting point for the Ruby DSL used to build
  # CPN models. The method CPN::DSLBuilder.build_net can be used to 
  # build a network (time based model) using the DSL methods page,
  # state, transition and arc. The DSL can be extended by code that
  # re-opens the DSLBuilder class, adds methods and/or calls the
  # before_load and after_load class methods to register addition
  # methods to run on builder instances.
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

    # To build a new network model, we specify the name, an optional path
    # to a file of DSL commands to load, and an option block of DSL commands
    # to execute. The order of interpretation is:
    # 1- any methods registered with the 'before_load' class method
    # 2- commands in file loaded
    # 3- commands in block
    # 4- any methods registered with the 'after_load' class method
    # The before_load and after_load methods are available for extension of the DSL.
    def self.build_net(name, path = nil, &block)
      net = Net.new(name)
      builder = DSLBuilder.new(net)
      builder.call_methods @before_load
      if path = builder.clean_path(path)
        net.path = path
        builder.instance_eval(File.read(path))
      end
      builder.instance_eval &block if(block_given?)
      builder.call_methods @after_load
      builder.result
    end

    def call_methods(methods=[])
      (methods||[]).each do |method|
        self.send method
      end
    end

    def self.before_load(*symbols)
      @before_load ||= []
      @before_load += symbols
    end

    def self.after_load(*symbols)
      @after_load ||= []
      @after_load += symbols
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

    # A page is a sub-component, which in itself is a petri net
    # This command will make that page, and it can then be used
    # later with the hs_transition code
    def page(name, path = nil, cmd_params = {}, &block)
      name = name.to_s.intern
      p = Page.new(name, @page)
      builder = DSLBuilder.new(p)
      # Parent params pass to child, but overridden by command-line params (in child only)
      puts "Parent params: #{self.params.inspect}" if($debug)
      puts "CMD params: #{cmd_params.inspect}" if($debug)
      builder.params.merge!(self.params).merge!(cmd_params)
      puts "Child params: #{builder.params.inspect}" if($debug)
      if path = clean_path(path)
        p.path = path
        puts "Loading page using builder: #{builder}" if($debug)
        builder.instance_eval(File.read(path))
        puts "Child params after loading #{path}: #{builder.params.inspect}" if($debug)
      end
      builder.instance_eval(&block) if(block_given?)
      puts "Child params after block: #{builder.params.inspect}" if($debug)

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

    def find_node(name)
      name = name.to_s.intern
      @page.states[name] || @page.transitions[name] || puts("State or Transition not found: #{name}")
    end

    def offset_position(position, origin)
      [:x, :y].each do |k|
        position[k] += origin[k].to_i if(position[k])
      end
      position
    end

    def layout(map={})
      puts "\n\nLAYOUT: #{map.inspect}\n\n"
      origin = {:x => 0, :y => 0}
      if map[:origin]
        if map[:origin][:node] && origin_node = find_node(map[:origin][:node])
          puts "Setting origin to #{origin_node.properties}"
          offset_position(origin,origin_node.properties)
        end
        [:x, :y].each do |k|
          origin[k] = map[:origin][k].to_i if(map[:origin][k])
        end
      end
      map.each do |name,p|
        if node = find_node(name)
          [:x, :y].each do |k|
            node.properties[k] = p[k] + origin[k] if(p[k])
          end
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

    # Make a special kind of transition that wraps a component
    # The component should already be defined previously using
    # the page command. It is possible to combine the page and
    # hs_transition commands by passing the path and optional
    # cmd_params to hs_transition directly.
    def hs_transition(name, path = nil, cmd_params = {}, &block)
      puts "Creating wrapper transition '#{name}', path=#{path}, params=#{cmd_params}"
      name = name.to_s.intern
      subpage = Page.new(name, @page)
      subpage.builder = self
      if path
        proto_name = "#{name}#{path.gsub(/\.rb$/i,'').split(/\//)[-1]}"
        prototype = page(proto_name, path, cmd_params)
        subpage.prototype = prototype
      end
      subpage.instance_eval &block if block_given?
      @page.add_transition(subpage)
    end

    def make_arc(from, to, options = {}, &block)
      # Convert input fields to Nodes in the network
      from,to = [from,to].map do |node|
        if node.is_a? CPN::Node
          node
        else
          node = @page.transitions[node.to_s.intern] || @page.states[node.to_s.intern] || raise("State or transition not found: #{node}")
        end
      end
      puts "Creating arc from[#{from.class}](#{from.name}) -> from[#{to.class}](#{to.name})"
      if(
        from.is_a?(CPN::State) && !to.is_a?(CPN::State) || 
        to.is_a?(CPN::State) && !from.is_a?(CPN::State)
      )
      # Build the arc and connect to state or transition
        a = Arc.new(from, to)
        a.expr = options[:expr] unless options[:expr].nil?
        a.hints = options[:hints] unless options[:hints].nil?
        a.instance_eval &block if block_given?
        from.outgoing << a
        to.incoming << a
        @page.add_arc(a)
      else
        raise "Cannot connect two elements that are not a state and a transition: #{from.name} -> #{to.name}"
      end
    end

    def arc(from, to, options = {}, &block)
      if options.is_a? String
        options = {:expr => options}
      end
      make_arc(from, to, options, &block)
      make_arc(to, from, options, &block) if(options[:bidirectional])
    end

  end # DLSBuilder

end

