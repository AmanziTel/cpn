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

    def contingency(alert_state, end_state, &block)
      if block_given?
        plan = ContingencyPlan.new(self, alert_state, end_state)
        plan.instance_eval(&block)
        puts "Created contingency plan with #{plan.checks.length} checks: #{plan}"
        plan.build_cpn
      else
        transition :Contingency
        arc alert_state, :Contingency
        arc :Contingency, end_state
      end
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

  end  #DSLBuilder

  class PlanStep
    attr_reader :name, :plan, :options, :transition
    def initialize(plan, name, typeName, options = {})
      @plan = plan
      @name = name
      @options = options
      @options[:duration] ||= 1
      @transition = builder.transition "#{typeName} #{name}"
    end
    def builder
      plan.builder
    end
    # Connect this step to another step (with intervening state)
    # Or connect to the end_state if no next step is found
    def connect_to(nextType, nextName)
      if nextName && (nextStep = plan.find_step(nextName))
        # Make an intermediate state, and connect trans->state->next
        state = builder.state "#{name} #{nextType}"
        state.properties[:size] = 'small'
        state.properties[:label] = nextType
        builder.arc transition, state, "p.ready_at(#{options[:duration].to_i})"
        builder.arc state, nextStep.transition, 'p'
      else
        # Connect directly to end state, or specified state
        next_state = plan.end_state
        next_state = plan.alert_state if(plan.alert_state == nextName)
        puts "Cannot find 'pass' step: #{nextName}" if(nextName)
        builder.arc transition, next_state, "p.ready_at(#{options[:duration].to_i})"
      end
    end
    def build
      connect_to 'Next', options[:next]
    end
  end

  class CheckStep < PlanStep
    attr_reader :pass, :fail
    def initialize(plan, name, options = {})
      super(plan, name, "Check", options)
    end
    def build
      ['Pass','Fail'].each do |result|
        connect_to result, options[result.downcase.intern]
      end
    end
  end

  class RepairStep < PlanStep
    def initialize(plan, name, options = {})
      super(plan, name, 'Repair', options)
    end
  end

  class ContingencyPlan
    attr_reader :builder, :checks, :repairs, :alert_state, :end_state, :start_name
    def initialize(builder, alert_state, end_state)
      @builder = builder
      @alert_state = alert_state
      @end_state = end_state
      @checks = []
      @repairs = []
    end
    def start_with(name)
      @start_name = name
    end
    def start
      @start ||= @start_name && find_step(@start_name) || checks[0]
    end
    def check(name, options = {})
      checks << CheckStep.new(self, name, options)
    end
    def repair(name, options = {})
      repairs << RepairStep.new(self, name, options)
    end
    def build_steps steps
      steps.each do |step|
        step.build
      end
    end
    def find_step name
      unless @steps
        @steps = {}
        @checks.each do |step|
          @steps[step.name] = step
          @steps["Check #{step.name}"] = step
        end
        @repairs.each do |step|
          @steps[step.name] = step
          @steps["Repair #{step.name}"] = step
        end
      end
      @steps[name]
    end
    def build_cpn
      build_steps repairs
      build_steps checks
      if alert_state && start
        builder.arc alert_state, start.transition, 'p'
      end
    end
  end
end

