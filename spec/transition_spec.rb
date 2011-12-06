require 'spec_helper'

describe CPN::Transition do

  context "1 transition with a guard, used as a 0..2 counter" do

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

    describe "the transition, " do
      before do
        @t = @cpn.transitions[:Incr]
      end

      it "should be enabled" do
        @t.should be_enabled
      end

      it "should have 0 distance to being valid" do
        @t.min_distance_to_valid_combo(0).should == 0
      end

      describe "after firing" do
        before do
          @t.occur
        end

        it "should still be enabled" do
          @cpn.states[:Counter].marking.first.should == 1
          @t.should be_enabled
        end

        describe "twice" do
          before do
            @t.occur
          end

          it "should not be enabled" do
            @cpn.states[:Counter].marking.first.should == 2
            @t.should_not be_enabled
          end

          it "should have nil (infinite) distance to being valid" do
            @t.min_distance_to_valid_combo(0).should be_nil
          end

        end
      end

    end
  end

  context "Timed net: 1 timed transition, used as a 3-second counter," do

    #  (Time)1@[3] ---{n}--> [Clock]
    #       ^                  |
    #       ---{n + 1@[+3]}<----
    before do
      @cpn = CPN.build :timed_ex1 do
        state(:Time) { |s| s.initial = "[ 1 ].ready_at(3)" }
        transition :Clock
        arc(:Time, :Clock) { |a| a.expr = "t, *" }
        arc(:Clock, :Time) { |a| a.expr = "[ t + 1 ].ready_at(+3)" }
      end
    end

    describe "the transition" do
      before do
        @t = @cpn.transitions[:Clock]
      end

      it "should be enabled" do
        @t.should be_enabled
      end

      it "should not be ready" do
        @t.should_not be_ready(@cpn.time)
      end

      it "should have a token on Time ready at 3" do
        @cpn.states[:Time].marking.first.ready?.should == 3
      end

      it "should have 3 time units until it's ready" do
        @t.min_distance_to_valid_combo(0).should == 3
        @t.min_distance_to_valid_combo(3).should == 0
        @t.min_distance_to_valid_combo(100).should == 0
      end

      describe "when advancing the time" do
        before do
          @cpn.advance_time
          @cpn.time.should == 3
        end

        it "should still be enabled" do
          @t.should be_enabled
        end

        it "should be ready" do
          @t.should be_ready(@cpn.time)
        end

        describe "when firing" do
          before do
            @cpn.occur_next
          end

          it "should still be enabled" do
            @t.should be_enabled
          end

          it "should not be ready" do
            @t.should_not be_ready(@cpn.time)
          end

          it "should have a token on Time ready at 6" do
            @cpn.states[:Time].marking.first.ready?.should == 6
          end
        end
      end

    end
  end

end

