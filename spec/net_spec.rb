require 'spec_helper'

describe CPN::Net do

  context "partial SendPacket diagram (1 transition)" do

    before do
      @cpn = CPN::build :fig1 do

        state :Send do |s|
          s.initial = "[ 1, 'x' ], [ 2, 'y' ]"
        end

        state :NextSend do |s|
          s.initial = "1"
        end

        transition :SendPacket

        arc :Send, :SendPacket do |a|
          a.expr = "n, p"
        end

        arc :NextSend, :SendPacket do |a|
          a.expr = "n"
        end

        state :A

        arc :SendPacket, :A do |a|
          a.expr = "[ n, p ]"
        end
      end
    end

    it "can enumerate the states" do
      enum_states = []
      @cpn.each_state do |s|
        enum_states << s.name
      end
      enum_states.should =~ [ :A, :NextSend, :Send ]
    end

    it "can enumerate the transitions" do
      enum_t = []
      @cpn.each_transition do |t|
        enum_t << t.name
      end
      enum_t.should =~ [ :SendPacket ]
    end

    describe "its arc from Send to SendPacket" do
      it "should have bindings {@n => 1, @p => 'x'},{@n => 2, @p => 'y'}" do
        bs = @cpn.arc_between(:Send, :SendPacket).bindings_hash
        bs.size.should == 2
        bs.should =~ [ { :n => 1, :p => "x" }, { :n => 2, :p => "y" } ]
      end
    end

    describe "its arc from NextSend to SendPacket" do
      it "should have binding {@n => 1}" do
        bs = @cpn.arc_between(:NextSend, :SendPacket).bindings_hash
        bs.should == [ { :n => 1 } ]
      end
    end

    describe "the transition SendPacket" do
      it "should be enabled" do
        @cpn.states[:NextSend].marking.should == [ 1 ]
        @cpn.transitions[:SendPacket].should be_enabled
      end

      it "should be able to occur, placing a token in A" do
        @cpn.states[:A].marking.should be_empty

        @cpn.transitions[:SendPacket].occur
        @cpn.transitions[:SendPacket].should_not be_enabled

        @cpn.states[:NextSend].marking.should be_empty 
        @cpn.states[:Send].marking.should == [ [ 2, "y" ] ] 
        @cpn.states[:A].marking.should == [ [ 1, "x" ] ]
      end

      describe "with a marking of '3' on NextSend" do
        before do
          @cpn.transitions[:SendPacket].should be_enabled
          @cpn.states[:NextSend].marking = [ 3 ]
        end

        it "should not be enabled" do
          @cpn.transitions[:SendPacket].should_not be_enabled
        end
      end

    end

  end

  context "A[42], B[42] --> T --> C, D" do
  # with no expressions should place a 42 token on C and on D

    before do
      @cpn = CPN.build :noexpr do

        state :A do |s|
          s.initial = "42"
        end
        state :B do |s|
          s.initial = "42"
        end
        state :C
        state :D

        transition :T

        arc :A, :T
        arc :B, :T
        arc :T, :C
        arc :T, :D
      end
    end

    describe "the transition T" do
      it "should be enabled" do
        @cpn.transitions[:T].should be_enabled
      end

      it "should be able to occur, placing a 42 token in C and D" do
        @cpn.transitions[:T].occur
        @cpn.transitions[:T].should_not be_enabled
        @cpn.states[:A].marking.should be_empty
        @cpn.states[:B].marking.should be_empty
        @cpn.states[:C].marking.should == [ 42 ]
        @cpn.states[:D].marking.should == [ 42 ]
      end
    end

  end

  context "Full SendPacket diagram" do

    before do
      @cpn = CPN.build :fig1 do
        # List of packets we want to send
        state :Send, "[1,'Modellin'], [2,'g and An'], [3,'alysis b'], [4,'y Means ']," +
                     "[5,'of Colou'], [6,'red Petr'], [7,'i Nets##']"

        # What packet number to send next
        state :NextSend, "1" 

        # Decide which packet to send (to A)
        transition :SendPacket

        # Keep the packet around since it may be dropped
        arc :Send, :SendPacket, "n, p"
        arc :SendPacket, :Send, "[ n, p ]"

        # Keep the packet number until it's acknowledged
        arc :NextSend, :SendPacket, "n"
        arc :SendPacket, :NextSend, "n"

        # Packets ready to send over the network
        state :A
        arc :SendPacket, :A, "[ n, p ]"

        # Actually send the packet
        transition :TransmitPacket
        arc :A, :TransmitPacket, "n, p"

        # Packets ready to receive
        state :B

        # State of the network - random, 0 or 1
        state :NetworkQuality, "1"
        transition :UpdateNetworkQuality
        arc :NetworkQuality, :UpdateNetworkQuality
        arc :UpdateNetworkQuality, :NetworkQuality, "if rand(100) > 80 then 1 else 0 end"
        arc :NetworkQuality, :TransmitPacket, "q"
        arc :TransmitPacket, :NetworkQuality, "q"

        # Transmit the packet to B if network quality is 1
        arc :TransmitPacket, :B, "[ n, p ] if q == 1"

        # Receive the packet, prepare to send acknowledge
        transition :ReceivePacket

        arc :B, :ReceivePacket, "n, p"

        # Packet numbers ready to acknowledge
        state :C

        arc :ReceivePacket, :C, "if n == k then k + 1 else k end"

        # Next packet number to acknowledge
        state :NextRec, "1"
        arc :NextRec, :ReceivePacket, "k"
        arc :ReceivePacket, :NextRec, "if n == k then k + 1 else k end"

        # Packets received
        state :Received, '""'
        arc :Received, :ReceivePacket, "str"
        arc :ReceivePacket, :Received, "if n == k then str + p else str end"

        # Packet numbers (acks) received
        state :D

        # Actually send the ack across the net, if quality is 1
        transition :TransmitAck
        arc :C, :TransmitAck, "n"
        arc :TransmitAck, :D, "n if q == 1"
        arc :NetworkQuality, :TransmitAck, "q"
        arc :TransmitAck, :NetworkQuality, "q"

        # Update NextSend
        transition :ReceiveAck
        arc :D, :ReceiveAck, "n"
        arc :NextSend, :ReceiveAck, "k"
        arc :ReceiveAck, :NextSend, "n"
      end
    end

   describe "the transition :UpdateNetworkQuality" do
      it "should be enabled" do
        @cpn.transitions[:UpdateNetworkQuality].should be_enabled
      end

      it "should be able to occur 50 times, placing both 0s and 1s in NetworkQuality" do
        qualities = []
        50.times do
          @cpn.transitions[:UpdateNetworkQuality].occur
          q = @cpn.states[:NetworkQuality].marking
          q.length.should == 1
          q.first.should be_between(0, 1)
          qualities << q.first
        end
        qualities.any? {|q| q == 0}.should be_true
        qualities.any? {|q| q == 1}.should be_true
      end
    end

    context "before any transitions have occurred" do
      describe "the transition SendPacket" do
        it "should be enabled" do
          @cpn.transitions[:SendPacket].should be_enabled
        end

        [ :TransmitPacket, :ReceivePacket, :TransmitAck, :ReceiveAck ].each do |t|
          describe "the transition #{t}" do
            it "should not be enabled" do
              @cpn.transitions[t].should_not be_enabled
            end
          end
        end

        it "should be able to occur twice, placing a [ 1, 'Modellin' ] token in A" do
          @cpn.transitions[:SendPacket].occur
          @cpn.transitions[:SendPacket].should be_enabled
          @cpn.states[:A].marking.should == [ [ 1, 'Modellin' ] ]

          @cpn.transitions[:SendPacket].occur
          @cpn.transitions[:SendPacket].should be_enabled
          @cpn.states[:A].marking.should == [ [ 1, 'Modellin' ], [ 1, 'Modellin' ] ]
        end
      end
    end

    context "after SendPacket" do
      before do
        @cpn.transitions[:SendPacket].occur
        @cpn.states[:A].marking.should == [ [ 1, 'Modellin' ] ]
        @cpn.states[:B].marking.should be_empty
      end

      [ :ReceivePacket, :TransmitAck, :ReceiveAck ].each do |t|
        describe "the transition #{t}" do
          it "should not be enabled" do
            @cpn.transitions[t].should_not be_enabled
          end
        end
      end

      describe "the transition :TransmitPacket" do
        it "is enabled" do
          @cpn.transitions[:TransmitPacket].should be_enabled
        end

        it "can occur, placing a token on B if NetworkQuality is 1" do
          @cpn.states[:NetworkQuality].marking.should == [ 1 ]
          @cpn.transitions[:TransmitPacket].occur
          @cpn.states[:A].marking.should be_empty
          @cpn.states[:B].marking.should == [ [ 1, 'Modellin' ] ]
          @cpn.states[:NetworkQuality].marking.should == [ 1 ]
        end

        it "can occur, placing nothing on B if NetworkQuality is 0" do
          @cpn.states[:NetworkQuality].marking = [ 0 ]
          @cpn.transitions[:TransmitPacket].occur
          @cpn.states[:A].marking.should be_empty
          @cpn.states[:B].marking.should be_empty
          @cpn.states[:NetworkQuality].marking.should == [ 0 ]
        end
      end

      context "and TransmitPacket" do
        before do
          @cpn.transitions[:TransmitPacket].occur
        end

        [ :TransmitPacket, :TransmitAck, :ReceiveAck ].each do |t|
          describe "the transition #{t}" do
            it "should not be enabled" do
              @cpn.transitions[t].should_not be_enabled
            end
          end
        end

        describe "the transition :ReceivePacket" do
          it "is enabled" do
            @cpn.transitions[:ReceivePacket].should be_enabled
          end

          it "can occur, placing @n+1 on C, appending @p to Received and increasing NextRec" do
            @cpn.states[:B].marking.should == [ [ 1, 'Modellin' ] ]
            @cpn.states[:C].marking.should be_empty
            @cpn.states[:Received].marking.should == [ "" ]
            @cpn.states[:NextRec].marking.should == [ 1 ]

            @cpn.transitions[:ReceivePacket].occur

            @cpn.states[:B].marking.should be_empty
            @cpn.states[:C].marking.should == [ 2 ]
            @cpn.states[:Received].marking.should == [ "Modellin" ]
            @cpn.states[:NextRec].marking.should == [ 2 ]
          end
        end

        context "and ReceivePacket" do
          before do
            @cpn.transitions[:ReceivePacket].occur
          end

          [ :TransmitPacket, :ReceivePacket, :ReceiveAck ].each do |t|
            describe "the transition #{t}" do
              it "should not be enabled" do
                @cpn.transitions[t].should_not be_enabled
              end
            end
          end

          describe "the transition :TransmitAck" do
            it "is enabled" do
              @cpn.transitions[:TransmitAck].should be_enabled
            end

            it "can occur, placing @n on D, if the NetworkQuality is 1" do
              @cpn.states[:NetworkQuality].marking.should == [ 1 ]
              @cpn.states[:C].marking.should == [ 2 ]
              @cpn.states[:D].marking.should be_empty

              @cpn.transitions[:TransmitAck].occur

              @cpn.states[:C].marking.should be_empty
              @cpn.states[:D].marking.should == [ 2 ]
            end

            it "can occur, placing nothing on D, if the NetworkQuality is 0" do
              @cpn.states[:NetworkQuality].marking = [ 0 ]
              @cpn.states[:C].marking.should == [ 2 ]
              @cpn.states[:D].marking.should be_empty

              @cpn.transitions[:TransmitAck].occur

              @cpn.states[:NetworkQuality].marking = [ 0 ]
              @cpn.states[:C].marking.should be_empty
              @cpn.states[:D].marking.should be_empty
            end
          end

          context "and TransmitAck" do
            before do
              @cpn.transitions[:TransmitAck].occur
            end

            [ :TransmitPacket, :ReceivePacket, :TransmitAck ].each do |t|
              describe "the transition #{t}" do
                it "should not be enabled" do
                  @cpn.transitions[t].should_not be_enabled
                end
              end
            end

            describe "the transition :ReceiveAck" do
              it "is enabled" do
                @cpn.transitions[:ReceiveAck].should be_enabled
              end

              it "can occur, placing @n on NextSend instead of its old value" do
                @cpn.states[:D].marking.should == [ 2 ]
                @cpn.states[:NextSend].marking.should == [ 1 ]

                @cpn.transitions[:ReceiveAck].occur

                @cpn.states[:D].marking.should be_empty
                @cpn.states[:NextSend].marking.should == [ 2 ]
              end
            end

          end
        end
      end
    end

    class StateObserver
      def update(state, op, token)
        puts "State update: #{state.name}, op: #{op}, token: #{token.inspect}"
      end
    end

    class TransitionObserver
      def update(transition)
        puts "Fire: #{transition.name}"
      end
    end

#    describe "after occurring 2000 times" do
#      before do
##        @cpn.states[:Received].add_observer(StateObserver.new)
##        @cpn.states[:NextSend].add_observer(StateObserver.new)
##        @cpn.transitions[:ReceivePacket].add_observer(TransitionObserver.new)
#        2000.times { @cpn.occur_next }
#      end
#
#      it "should have sent, received and acknowledged all messages" do
#        @cpn.states[:Received].marking.should == [
#          "Modelling and Analysis by Means of Coloured Petri Nets##"
#        ]
#        @cpn.states[:NextSend].marking.should == [ 8 ]
#      end
#    end

  end

  context "Timed net: 1 timed transition, used as a 3-second counter," do

    #  (Time)1@[3] ---{n}--> [Clock]
    #       ^                  |
    #       ---{n + 1@[+3]}<----
    before do
      @cpn = CPN.build :timed_ex1 do
        state :Time { |s| s.initial = "1.ready_at(3)" }
        transition :Clock
        arc :Time, :Clock { |a| a.expr = "n" }
        arc :Clock, :Time { |a| a.expr = "(n + 1).ready_at(+3)" }
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

