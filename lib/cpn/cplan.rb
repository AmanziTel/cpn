require File.expand_path("#{File.dirname __FILE__}/dsl_builder")
require File.expand_path("#{File.dirname __FILE__}/net")

module CPN

  # We extend the CPN DSL with support for Contingency Planning.
  class DSLBuilder

    after_load :setup_threats

    def contingency(alert_state, end_state, path = nil, &block)
      plan = ContingencyPlan.new(self, alert_state, end_state)
      if path = self.clean_path(path)
        plan.instance_eval(File.read(path))
      end
      plan.instance_eval(&block) if(block_given?)
      puts "Created contingency plan with #{plan.checks.length} checks: #{plan}"
      plan.build_cpn
    end

    def threat(vulnerability, description, attributes = {}, &block)
      @threats ||= {}
      threat = Threat.new(description, vulnerability, attributes)
      threat.builder = self
      threat.net = @page.net
      @page.net.threats << threat
      @threats[threat.name] = threat
      @threats[threat.name].instance_eval(&block) if(block_given?)
    end

    def threats(*args)
      vulnerability = args.shift
      args.each do |description|
        threat vulnerability, description
      end
    end

    def recovery(threat_name, name)
      if threat = @threats && @threats[threat_name]
        threat.recovery = name
      else
        raise "Recovery '#{name}' cannot find matching threat: #{threat_name}"
      end
    end

    def setup_threats
      @page.net.setup_threats
    end

  end

  # Re-open the net class and add a results method for the CPLAN results
  class Net
    alias_method :network_reset, :reset
    def reset
      network_reset
      setup_threats
    end
    def setup_threats
      threats.each do |threat|
        puts "Processing threat: #{threat}"
        if threat.state
          threat.state.add_token threat.token, false if(threat.token)
          if threat.recovery
            if threat.transition
              threat.state.properties[:recoveries] ||= []
              threat.state.properties[:recoveries] << threat.recovery
              threat.transition.properties[:vulnerability] = threat.vulnerability
              threat.transition.properties[:threat] = threat.name
            else
              raise "Cannot configure threat '#{threat}': No such recovery transition '#{threat.recovery}'"
            end
          else
            raise "Threat '#{threat}' invalid: no recovery defined"
          end
        else
          raise "Cannot configure threat '#{threat}': No such vulnerability state '#{threat.vulnerability}'"
        end
      end
    end
    def threats
      @threats ||= []
    end
    def results
      @results_net_time = time
      if @resuls.nil? || @prev_results_net_time.nil? || @prev_results_net_time != @results_net_time
        failed = []
        @results = threats.map do |threat|
          failed << threat.name unless(threat.token.recovery)
          {:threat => {:name => threat.name, :recovery => threat.token.recovery, :path => threat.token.transitions}}
        end
        @results.unshift(:failed => failed) if(failed.length>0)
      end
      @prev_results_net_time = @results_net_time
      @results
    end
  end

  module ThreatToken
    attr_accessor :threat, :recovery
    def on_transition(transition)
      if self.threat && transition.properties[:threat] && transition.properties[:threat].to_s == self.threat.to_s
        self.recovery = transition.name
      end
      @transitions ||= []
      @transitions << transition.name
    end
    def transitions
      @transitions ||= []
    end
  end

  class Threat
    attr_reader :name, :vulnerability, :attributes, :after
    attr_accessor :recovery, :builder, :net
    def initialize(name, vulnerability, attributes = {})
      @builder = builder
      @name = name.split(/@/)[0]
      @vulnerability = vulnerability
      @attributes = attributes
      @after = name.split(/@/)[1] || attributes[:ready_at] || attributes[:after]
    end
    def state
      @state ||= vulnerability && builder.find_node(vulnerability)
    end
    def transition
      @transition ||= recovery && builder.find_node(recovery)
    end
    def reset
      @token = nil
      token
    end
    def token
      unless @token
        @token = attributes[:token] || name
        @token.ready_at(after)
        class << @token
          include ThreatToken
        end
        @token.threat = self
      end
      @token
    end
    def to_s
      name
    end
  end

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
          :token_match_transitions => token_matches_keys.map{|k| "#{k} #{name}"},
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
      if options[:threat]
        builder.recovery options[:threat], transition_name
      end
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
    def recovery(threat_name, name)
      if repair = @repairs.reject {|repair| !(repair.transition_name === name)}[0]
        repair.options[:threat] = threat_name
        builder.recovery threat_name, repair.transition_name
      else
        raise "Recovery '#{name}' was not found in known repair steps. Be sure to define the recovery after the repair."
      end
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

  end # ContingencyPlan

end

