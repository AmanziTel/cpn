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

    def delete(t,error_on_missing=true)
      i = @tokens.index(t)
      if i
        @tokens.delete_at(i)
      elsif error_on_missing
        raise "Unknown token #{t} (#{@tokens.inspect})"
      end
    end

    def fuse_with(marking)
      if empty?
        marking.each do |t|
          @tokens << t
        end
      end
    end

    def to_hash
      @tokens.map do |t|
        t.respond_to?(:ready?) ? t.clone : t
      end
    end

    def as_json
      @tokens.map do |t|
        t.respond_to?(:as_token_text) ? t.as_token_text : t.inspect
      end
    end

    def to_s
      @tokens.to_s
    end
  end
end

