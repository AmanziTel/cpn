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

    def identity
      @identity ||= "#{self.class.to_s.split(/\:+/)[-1].downcase.pluralize}/#{name}"
    end

    def qname
      [container && container.qname, name].compact.join("::")
    end

    def a2h(array, use_2h = false)
      array.map do |v|
        v.respond_to?('to_hash') ? v.to_hash : (v && v.clone.to_s)
      end
    end

    # Utility method to make the data structure easier to convert to JSON
    def to_hash(detailed=true)
      h = {:name => name, :identity => identity}
      h = h.merge(
        incoming.length>0 ? {:incoming => a2h(incoming)} : {}
      ).merge(
        outgoing.length>0 ? {:outgoing => a2h(outgoing)} : {}
      ).merge(
        properties.length>0 ? {:properties => properties.clone} : {}
      ) if(detailed)
      h
    end

    def net
      container && container.net
    end

  end
end

