require 'spec_helper'

describe CPN::Transition do

  context "1 transition with 2 incoming arcs" do

    before do
      @cpn = CPN.build :ex1 do

        state :A do |s|
          s.initial = "'a'"
        end

        state :B do |s|
          s.initial = "'a', 'b'"
        end

        transition :T

        arc :A, :T do |a|
          a.expr = "t"
        end

        arc :B, :T do |a|
          a.expr = "t"
        end

      end
    end

    describe "arc token combinations for the transition T" do
      before do
        @t = @cpn.transitions[:T]
      end

      it "should have none for an empty list of arcs" do
        atcs = CPN::ArcTokenCombination.all([])
        atcs.should be_empty
      end

      it "should have 1 given one incoming arc with one token" do
        atcs = CPN::ArcTokenCombination.all([ @cpn.arc_between(:A, :T) ])
        atcs.length.should == 1
        atcs.first.first.token.should == 'a'
        atcs.first.first.arc.should == @cpn.arc_between(:A, :T)
      end

      it "should have 2 given one incoming arc with two tokens" do
        atcs = CPN::ArcTokenCombination.all([ @cpn.arc_between(:B, :T) ])
        atcs.length.should == 2
        atcs.first.length.should == 1
        atcs.first.first.token.should == 'a'
        atcs.first.first.arc.should == @cpn.arc_between(:B, :T)
        atcs.last.length.should == 1
        atcs.last.first.token.should == 'b'
        atcs.last.first.arc.should == @cpn.arc_between(:B, :T)
      end

      it "should have 2 given two incoming arcs with 1 and 2 tokens" do
        atcs = CPN::ArcTokenCombination.all(@t.incoming)
        atcs.length.should == 2
        atcs.first.length.should == 2
        atcs.first.first.token.should == 'a'
        atcs.first.first.arc.should == @cpn.arc_between(:A, :T)
        atcs.first.last.token.should == 'a'
        atcs.first.last.arc.should == @cpn.arc_between(:B, :T)

        atcs.last.length.should == 2
        atcs.last.first.token.should == 'a'
        atcs.last.first.arc.should == @cpn.arc_between(:A, :T)
        atcs.last.last.token.should == 'b'
        atcs.last.last.arc.should == @cpn.arc_between(:B, :T)
      end

      it "should be enabled" do
        @t.should be_enabled
      end

    end

  end

  context "1 transition with a guard, used as a 0..2 counter" do

    #  (Counter)0 ---{n}--> (Incr){n < 2}
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

        end
      end

    end
  end

end
