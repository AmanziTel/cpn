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

    def contingency(alert_state, end_state, path = nil, &block)
      plan = ContingencyPlan.new(self, alert_state, end_state)
      if path = self.clean_path(path)
        plan.instance_eval(File.read(path))
      end
      plan.instance_eval(&block) if(block_given?)
      puts "Created contingency plan with #{plan.checks.length} checks: #{plan}"
      plan.build_cpn
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
      @page.states[name] || @page.transitions[name] || puts("State not found: #{name}")
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
    attr_reader :name, :type_name, :plan, :options, :transition, :transition_name, :verb, :next_step
    attr_accessor :input_state
    def initialize(plan, name, prev_step, type_name, options = {})
      @plan = plan
      @name = name
      @type_name = type_name
      @options = options
      @options[:duration] ||= 1
      @verb = options[:verb] || type_name
      @transition_name = name =~ /^#{verb}/ ? name : "#{verb} #{name}"
      prev_step && prev_step.next_step = self
    end
    def builder
      plan.builder
    end
    def next_step=(step)
      @next_step = step
      options[:next] ||= @next_step.transition_name
    end
    def transition
      @transition ||= builder.transition transition_name
    end
    # Connect this step to another step (with intervening state)
    # Or connect to the end_state if no next step is found
    def get_next_state(nextType, nextName)
      next_state = nil
      puts "\n\n#{name} searching for next state using type[#{nextType}] and name[#{nextName}]"
      if nextName && (nextStep = plan.find_step(nextName))
        # Make an intermediate state, and connect trans->state->next
        next_state = nextStep.input_state
        if next_state
          puts "\tUsing existing output state '#{next_state}' for '#{self}'"
        else
          puts "\tMaking new output state '#{name} #{nextType}' for '#{self}'"
          next_state = builder.state "#{transition_name} #{nextType}"
          next_state.properties[:size] = 'small'
          next_state.properties[:label] = nextType
          next_state.properties[:color] = case nextType.downcase.intern
            when :pass
              'green'
            when :fail
              'red'
            else
              'blue'
            end
          nextStep.input_state = next_state
        end
      elsif plan.alert_state == nextName
        puts "\tNext state is alert state: #{plan.alert_state}"
        next_state = plan.alert_state
      elsif nextName && (next_state = builder.result.states[nextName.intern])
        puts "\tFound next state in external network: #{next_state}"
      elsif nextName
        puts "\tState not found anywhere, not even in external states: #{builder.result.states.keys.inspect}"
        ss = builder.result.states[nextName]
        puts "\tExternal states yields: #{nextName} => #{ss}"
      end
      # Connect directly to end state if nothing else worked
      next_state ||= plan.end_state
    end
    def input_state=(input_state)
      if @input_state
        puts "Trying to change input state from '#{@input_state}' to '#{input_state}'" if(@input_state != input_state)
      else
        @input_state = input_state
        builder.arc input_state, transition, 'p'
      end
      @input_state
    end
    def arc_expression
      expression = 'p'
      expression = "\"#{options[:prefix]} #\{#{expression}\}\"" if(options[:prefix])
      expression = "[#{expression}]. reject{|v| v=~/#{options[:reject]}/}" if(options[:reject])
      expression += ". #{options[:expr]}" if(options[:expr])
      expression += ". ready_at(#{options[:duration].to_i})" if(options[:duration])
      expression
    end
    def build
      builder.arc transition, get_next_state('Next',options[:next]), arc_expression
    end
    def to_s
      "#{type_name}Step[#{name}]: #{options.inspect}"
    end
  end

  class CheckStep < PlanStep
    attr_reader :pass, :fail, :template
    def initialize(plan, name, prev_step, options = {})
      super(plan, name, prev_step, "Check", options)
      @transition_name = name
      @template = "Check #{name}"
    end
    def next_step=(step)
      @next_step = step
      options[:fail] ||= @next_step.transition_name
    end
    def token_matches
      unless @token_matches
        @token_matches = {}
        options[:match] ||= options[:not]
        @token_matches['Pass'] = options[:expr] || (options[:match] && "token =~ /#{options[:match]}/") || 'token.empty?'
        @token_matches['Fail'] = "!(#{token_matches['Pass']})"
        if options[:not]
          o = @token_matches['Pass']
          @token_matches['Pass'] = @token_matches['Fail']
          @token_matches['Fail'] = o
        end
      end
      @token_matches
    end
    def token_matches_keys
      # Return ['Pass','Fail'] in that order
      token_matches.keys.sort.reverse
    end
    def token_matches_values
      token_matches_keys.map {|k| @token_matches[k]}
    end
    def input_state=(input_state)
      if @input_state
        puts "Trying to change input state from '#{@input_state}' to '#{input_state}'" if(@input_state != input_state)
      else
        @input_state = input_state
        puts "\tFusing starting state '#{input_state}' with :Input for '#{self}'"
        transition.fuse input_state, template
      end
      @input_state
    end
    def transition
      unless @transition
        # Create the transition as a sub-page
        @transition = builder.hs_transition transition_name
        @transition.properties[:label] = token_matches_values[0]

        # Make the template and then create the transition based on it
        puts "Making transition '#{name}' using component in prototype '#{template}'"
        builder.page template, "/nets/IT/Components/TokenMatchSwitch.rb",
          :token_match_expressions => token_matches_values,
          :token_match_transitions => token_matches_keys.map{|k| "#{k} It"},
          :token_match_states => token_matches_keys,
          :token_match_input => template
        @transition.prototype = template
      end
      @transition
    end
    def build
      token_matches_keys.each_with_index do |match,index|
        next_state = get_next_state(match,options[match.downcase.intern])
        puts "\tFusing ending state '#{next_state}' with '#{match}'"
        transition.fuse next_state, match
      end
    end
  end

  class RepairStep < PlanStep
    def initialize(plan, name, prev_step, options = {})
      super(plan, name, prev_step, 'Repair', options)
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
      @layout_map = {}
    end
    def start_with(name)
      @start_name = name
    end
    def start
      @start ||= @start_name && find_step(@start_name) || checks[0]
    end
    def check(name, options = {})
      @step = CheckStep.new(self, name, @step, options)
      checks << @step
    end
    def repair(name, options = {})
      @step = RepairStep.new(self, name, @step, options)
      repairs << @step
    end
    def layout(map={})
      @layout_map.merge! map
    end
    def find_step name
      unless @steps
        @steps = {}
        [@checks,@repairs].flatten.each do |step|
          @steps[step.name] = step
          @steps[step.transition_name] = step
          @steps["#{step.type_name} #{step.name}"] = step
        end
      end
      @steps[name]
    end
    def fill_layout(steps, offset = {:x => 0, :y => 100})
      @prev_position ||= {:x => 0, :y => 0}
      steps.each do |step|
        puts "Setting layout position for #{step.transition_name}"
        puts "\tPrevious position: #{@prev_position.inspect}"
        puts "\tCurrent position: #{@layout_map[step.transition_name].inspect}"
        @layout_map[step.transition_name] ||= {}
        @layout_map[step.transition_name][:x] ||= @prev_position[:x] + offset[:x].to_i
        @layout_map[step.transition_name][:y] ||= @prev_position[:y] + offset[:y].to_i
        @prev_position = @layout_map[step.transition_name].clone
        puts "\tNew position: #{@layout_map[step.transition_name].inspect}"
        puts "\tNext previous position: #{@prev_position.inspect}"
      end
    end
    def build_cpn
      check :It unless(checks.length > 0)
      repair :It unless(repairs.length > 0)
      puts "Setting first alert state '#{alert_state}' to first check: #{start}"
      start.input_state = alert_state
      [repairs,checks].each do |steps|
        puts "Building #{steps.length} Steps: #{steps.join(', ')}"
        steps.each do |step|
          step.build
        end
      end
      puts "\n\nLAYOUT1: #{@layout_map.inspect}\n\n"
      fill_layout(checks)
      @prev_position[:x] += 200
      @prev_position[:y] += 100
      fill_layout(repairs, :y => -100)
      puts "\n\nLAYOUT2: #{@layout_map.inspect}\n\n"
      if alert_state
        @layout_map[:origin] ||= {}
        @layout_map[:origin][:node] ||= alert_state
      end
      builder.layout @layout_map
    end
  end
end

