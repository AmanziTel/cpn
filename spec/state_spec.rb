require 'spec_helper'

describe CPN::State do

  context "counter state with increment transition" do

    #  (Counter)0 ---{n}--> [Incr]{n < 2}
    #       ^                  |
    #       --------{n+1}<------
    before do
      @cpn = CPN.build :ex2 do

        state :Counter do |s|
          s.initial = "0"
        end

        transition :Incr do |t|
          t.guard = "n < 2"
        end

        arc :Counter, :Incr do |a|
          a.expr = "n"
        end

        arc :Incr, :Counter do |a|
          a.expr = "n + 1"
        end

      end
    end

    describe "the state, " do
      before do
        @s = @cpn.states[:Counter]
        @t = @cpn.transitions[:Incr]
      end

      it "should hold [ 0 ]" do
        @s.marking.to_a.should == [ 0 ]
      end

      describe "after firing the transition" do
        before do
          @listener = []
          def @listener.updated(source, op, marking)
            self << [ source, op, marking ]
          end
          @s.add_observer(@listener, :updated)
          @t.occur
        end

        it "should hold [ 1 ]" do
          @s.marking.to_a.should == [ 1 ]
        end

        it "should have fired the listener with token_removed, token_added" do
          @listener.should == [ [ @s, :token_removed, [] ], [ @s, :token_added, [ 1 ] ] ]
        end

      end
    end
  end
end

