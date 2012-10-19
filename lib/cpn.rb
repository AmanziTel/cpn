# This is the start of the CPN library. Requiring this fle will
# require all the files in cpn/*.rb. Also we add some methods
# to objects likely to be used as tokens in the petri net.

module CPN
  STATE_EVENTS = [ :state_changed ]
  TRANSITION_EVENTS = [ :before_fire, :after_fire ]
  NET_EVENTS = [ :tick ]
  ALL_EVENTS = STATE_EVENTS + TRANSITION_EVENTS + NET_EVENTS

  # This module can be applied to objects likely to be used as tokens
  # in the CPN. It allows the token to have an available time, so that
  # transitions do not fire until the token is available. For example,
  # extend String with this, then you can create a future available
  # token on a state using:
  #  state :Emergency, "Fire Started".ready_at(50)
  #
  # WARNING: Do not add this capability to Fixnum and Float. The reason is
  # two fold:
  # - any primitive types are immutable, and so a=a+1 will generate a new
  #   object without the settings of the previous one
  # - instances are common thought the runtime. This means that one instance
  #   of 0 is the same object as another instance of 0, so you cannot have
  #   two tokens with the same value, but different available settings.
  # The solution is to make a token like [0], instead of 0, and set the
  # availability on the enclosing array.
  module TimedAvailability
    def ready_at(t)
      puts "Setting token availability #{self}@#{t}" if($debug)
      @cpn_available = t
      self
    end

    def network=(network)
      @network = network
    end

    def ready_in(t)
      @cpn_available = t + (@network && @network.time).to_i
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
# Warning. Do not add this capability to Fixnum and Float. Read why
# in the module definition comments above.

class String
  include CPN::TimedAvailability
  def empty?
    self.length == 0
  end
end

class Array
  include CPN::TimedAvailability
  def empty?
    self.length == 0
  end
end

class Hash
  include CPN::TimedAvailability
  def empty?
    self.length == 0
  end
end


