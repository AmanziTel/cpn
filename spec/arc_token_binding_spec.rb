require 'spec_helper'

describe CPN::ArcTokenBinding do

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
        atcs = CPN::ArcTokenBinding.product([])
        atcs.should be_empty
      end

      it "should have 1 given one incoming arc with one token" do
        atcs = CPN::ArcTokenBinding.product([ @cpn.arc_between(:A, :T) ])
        atcs.length.should == 1
        atcs.first.first.token.should == 'a'
        atcs.first.first.arc.should == @cpn.arc_between(:A, :T)
        atcs.first.first.ready_distance(0).should == 0
      end

      it "should have 2 given one incoming arc with two tokens" do
        atcs = CPN::ArcTokenBinding.product([ @cpn.arc_between(:B, :T) ])
        atcs.length.should == 2
        atcs.first.length.should == 1
        atcs.first.first.token.should == 'a'
        atcs.first.first.arc.should == @cpn.arc_between(:B, :T)
        atcs.first.first.ready_distance(0).should == 0
        atcs.last.length.should == 1
        atcs.last.first.token.should == 'b'
        atcs.last.first.arc.should == @cpn.arc_between(:B, :T)
        atcs.last.first.ready_distance(0).should == 0
      end

      it "should have 2 given two incoming arcs with 1 and 2 tokens" do
        atcs = CPN::ArcTokenBinding.product(@t.incoming)
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

end
