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

    #  (Time)[0]@[3] ---{t}--> [Clock]
    #       ^                  |
    #       ------{t}@[+3]}<----
    before do
      @cpn = CPN.build :timed_ex1 do
        state(:Time) { |s| s.initial = "[ 0 ].ready_at(2)" }
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

      it "should have a token on Time ready at 2" do
        @cpn.states[:Time].marking.first.ready?.should == 2
      end

      it "should have 2 time units until it's ready" do
        @t.min_distance_to_valid_combo(0).should == 2
        @t.min_distance_to_valid_combo(2).should == 0
        @t.min_distance_to_valid_combo(100).should == 0
      end

      describe "when advancing the time" do
        before do
          @cpn.advance_time
          @cpn.time.should == 2
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

          it "should have a token on Time ready at 5" do
            @cpn.states[:Time].marking.first.ready?.should == 5
          end

          describe "and advancing time and occurring again" do
            before do
              @cpn.advance_time
              @cpn.time.should == 5
              @cpn.occur_next
            end
            it "should be enabled" do
              @t.should be_enabled
            end
            it "should have a token on Time ready at 8" do
              @cpn.states[:Time].marking.first.ready?.should == 8
            end
          end
        end
      end

    end
  end

  context "Timed net: 2 transitions, only one sets the time of tokens," do

    #  (Time1)t@2 -----> [Clock1] ----> (Time2) --{t}--> [Clock2]
    #       ^                                               |
    #       ---------------------{t}@[+3]}<------------------
    before do
      @cpn = CPN.build :timed_ex2 do
        state(:Time1) { |s| s.initial = "{ :id => 27 }.ready_at(2)" }
        state(:Time2)
        transition :Clock1
        transition :Clock2
        arc(:Time1, :Clock1)
        arc(:Clock1, :Time2)
        arc(:Time2, :Clock2) { |a| a.expr = "t" }
        arc(:Clock2, :Time1) { |a| a.expr = "t.ready_at(+3)" }
      end
    end

    describe "the Clock2 transition" do
      before do
        @t = @cpn.transitions[:Clock2]
      end

      it "should not be enabled" do
        @t.should_not be_enabled
      end

      it "should not be ready" do
        @t.should_not be_ready(@cpn.time)
      end

      it "should have nil time units until it's ready" do
        @t.min_distance_to_valid_combo(0).should be_nil 
      end

      describe "when advancing the time and occurring" do
        before do
          @cpn.advance_time
          @cpn.occur_next.should_not be_nil
          @cpn.time.should == 2
        end

        it "should be enabled" do
          @t.should be_enabled
        end

        it "should be ready" do
          @t.should be_ready(@cpn.time)
        end

        it "should have 0 time units until it's ready" do
          @t.min_distance_to_valid_combo(@cpn.time).should == 0
        end
      end
    end
  end

  context "Timed net with multiple ready tokens" do
    before do
      @cpn = CPN.build :timed_ex3 do
        state(:Source) { |s| s.initial = "{ :id => 3 }.ready_at(3), { :id => 4 }.ready_at(4), { :id => 1 }.ready_at(1)" }
        state :Dest
        transition :T
        arc :Source, :T
        arc :T, :Dest
      end
    end

    describe "the T transition" do
      before do
        @t = @cpn.transitions[:T]
      end

      it "should be enabled and ready at 4" do
        @t.should be_enabled
        @t.should be_ready(4)
      end

      it "should occur with the lowest timed token first" do
        @t.occur(4).should_not be_nil
        @cpn.states[:Dest].marking.should == [ { :id => 1 } ]
      end
    end
  end

end

