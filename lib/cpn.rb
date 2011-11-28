
module CPN
  def self.build(name, &block)
    Net.build(name, &block)
  end

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

# Include HasTimedAvailability into Fixnum and Array
class Fixnum
  include CPN::TimedAvailability
end

class String
  include CPN::TimedAvailability
end

class Array
  include CPN::TimedAvailability
end
