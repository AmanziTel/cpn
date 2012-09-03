module CPN

  # This is the basic unit of a CPN. The Node has a name,
  # properties and incoming/outgoing connections. Pages
  # contain and extend Node, allowing for nesting of subnets.
  class Node
    attr_accessor :name, :container
    attr_accessor :incoming, :outgoing
    attr_accessor :properties

    def initialize(name)
      @name = name
      @incoming, @outgoing = [], []
      @properties = {}
    end

    def qname
      [container && container.qname, name].compact.join("::")
    end

    def net
      container && container.net
    end

  end
end

