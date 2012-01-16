require 'spec_helper'

describe CPN::JSONBuilder do

  context "partial SendPacket diagram (1 transition)" do

    before do
      @cpn = CPN::build_json(:fig1, JSON.generate(
        { :network => {
            :states => [
              { :name => "Send", :marking => "[ 1, 'x' ], [ 2, 'y' ]", :properties => { :x => 100, :y => 150 } },
              { :name => "NextSend", :marking => "1" },
              { :name => "A" },
            ],
            :transitions => [
              { :name => "SendPacket", :guard => "n < 10", :properties => { :description => "Send a packet" } }
            ],
            :arcs => [
              { :from => "Send", :to => "SendPacket", :expr => "n, p" },
              { :from => "NextSend", :to => "SendPacket", :expr => "n" },
              { :from => "SendPacket", :to => "A", :expr => "[ n, p ]" }
            ]
          }
        }))
    end

    it "can get the properties of a state" do
      @cpn.states["Send"].properties["x"].should == 100
      @cpn.states["Send"].properties["y"].should == 150
    end

    it "can get the marking of a state" do
      @cpn.states["Send"].marking.should =~ [ [ 1, "x" ], [ 2, "y" ] ]
    end

    it "can get the guard of a transition" do
      @cpn.transitions["SendPacket"].guard.should == "n < 10"
    end

    it "can get the properties of a transition" do
      @cpn.transitions["SendPacket"].properties["description"].should == "Send a packet"
    end

    describe "its arc from Send to SendPacket" do
      it "should have bindings { n => 1, p => 'x'},{ n => 2, p => 'y'}" do
        bs = @cpn.arc_between("Send", "SendPacket").bindings_hash
        bs.size.should == 2
        bs.should =~ [ { :n => 1, :p => "x" }, { :n => 2, :p => "y" } ]
      end
    end

    describe "its arc from NextSend to SendPacket" do
      it "should have binding { n => 1}" do
        bs = @cpn.arc_between("NextSend", "SendPacket").bindings_hash
        bs.should == [ { :n => 1 } ]
      end
    end

    describe "the transition SendPacket" do
      it "should be enabled" do
        @cpn.states["NextSend"].marking.should == [ 1 ]
        @cpn.transitions["SendPacket"].should be_enabled
      end
    end
  end

end

