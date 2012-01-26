
module CPN
  STATE_EVENTS = [ :token_added, :token_removed ]
  TRANSITION_EVENTS = [ :before_fire, :after_fire ]
  NET_EVENTS = [ :tick ]
  ALL_EVENTS = STATE_EVENTS + TRANSITION_EVENTS + NET_EVENTS

  module TimedAvailability
    def ready_at(t)
      @cpn_available = t
      self
    end

    def ready?
      @cpn_available
    end
  end
end

Dir.glob "#{File.dirname __FILE__}/cpn/*.rb" do |f|
  require File.expand_path("#{File.dirname __FILE__}/cpn/" +
                           File.basename(f, '.rb'))
end

# Include HasTimedAvailability into a few classes often used as tokens
class String
  include CPN::TimedAvailability
end

class Array
  include CPN::TimedAvailability
end

class Hash
  include CPN::TimedAvailability
end
