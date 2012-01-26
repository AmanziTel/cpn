module CPN
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
      qn = name.to_s
      qn = "#{@container.qname}::#{qn}" if @container
      qn
    end

    def net
      container && container.net
    end

  end
end

