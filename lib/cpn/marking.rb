require 'observer'

module CPN
  class Marking
    include Observable
    include Enumerable

    def initialize
      @tokens = []
    end

    def set(tokens)
      @tokens = []
      changed
      notify_observers(self, :token_removed, [])
      @tokens = tokens
      changed
      notify_observers(self, :token_added, @tokens.clone)
    end

    def empty?
      @tokens.empty?
    end

    def each &blk
      @tokens.each &blk
    end

    def <<(t)
      @tokens << t

      changed
      notify_observers(self, :token_added, @tokens.clone)
    end

    def delete(t)
      i = @tokens.index(t)
      raise "Unknown token #{t}" if i.nil?
      @tokens.delete_at(i)

      changed
      notify_observers(self, :token_removed, @tokens.clone)
    end

    def to_s
      @tokens.to_s
    end
  end
end

