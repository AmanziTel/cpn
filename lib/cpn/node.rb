require 'observer'

module CPN
  class Node
    include Observable

    attr_accessor :name, :description
    attr_accessor :incoming, :outgoing
    attr_accessor :properties

    def initialize(name)
      @name = name
      @incoming, @outgoing = [], []
      @properties = {}
    end

  end
end

