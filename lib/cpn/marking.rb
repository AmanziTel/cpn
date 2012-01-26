require File.expand_path("#{File.dirname __FILE__}/observable.rb")

module CPN
  class Marking
    include CPN::Observable
    include Enumerable

    def initialize
      observable_event_types = [ :token_remove, :token_added ]
      @tokens = []
    end

    def set(tokens)
      @tokens = []
      fire(:token_removed)
      @tokens = tokens
      fire(:token_added)
    end

    def empty?
      @tokens.empty?
    end

    def each &blk
      @tokens.each &blk
    end

    def <<(t)
      @tokens << t

      fire(:token_added)
    end

    def delete(t)
      i = @tokens.index(t)
      raise "Unknown token #{t}" if i.nil?
      @tokens.delete_at(i)

      fire(:token_removed)
    end

    def to_s
      @tokens.to_s
    end
  end
end

