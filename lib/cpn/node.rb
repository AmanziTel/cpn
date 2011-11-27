require 'observer'

module CPN
  class Node
    include Observable

    attr_accessor :name, :incoming, :outgoing
    attr_accessor :x, :y

    def initialize(name)
      @name = name
      @incoming, @outgoing = [], []
    end

  end
end

