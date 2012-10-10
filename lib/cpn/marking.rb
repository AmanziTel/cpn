require File.expand_path("#{File.dirname __FILE__}/observable.rb")

module CPN
  class Marking
    include CPN::Observable
    include Enumerable

    event_source :updated

    def initialize
      @tokens = []
    end

    def set(tokens)
      @tokens = tokens
    end

    def empty?
      @tokens.empty?
    end

    def each &blk
      @tokens.each &blk
    end

    def <<(t)
      @tokens << t
    end

    def length
      @tokens.length
    end

    def delete(t)
      i = @tokens.index(t)
      raise "Unknown token #{t}" if i.nil?
      @tokens.delete_at(i)
    end

    def fuse_with(marking)
      if empty?
        marking.each do |t|
          @tokens << t
        end
      end
    end

    def to_hash
      @tokens
    end

    def to_s
      @tokens.to_s
    end
  end
end

