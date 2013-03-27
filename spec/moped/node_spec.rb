require "spec_helper"

describe Moped::Node, replica_set: true do

  let(:replica_set_node) do
    @replica_set.nodes.first
  end

  let(:node) do
    Moped::Node.new(replica_set_node.address)
  end

  describe "#disconnect" do

    context "when the node is running" do

      before do
        node.disconnect
      end

      it "disconnects from the server" do
        node.should_not be_connected
      end
    end
  end

  describe "#peers" do

    let(:node) do
      described_class.new("127.0.0.1:27017")
    end

    let(:info) do
      {
         "setName"   => "moped_dev",
         "ismaster"  => true,
         "secondary" => false,
         "hosts"     => [ "127.0.0.1:27017", "localhost:27017" ],
         "primary"   => "127.0.0.1:27017",
         "me"        => "127.0.0.1:27017",
         "ok"        => 1.0
      }
    end

    context "when the hosts contain the primary" do

      before do
        node.should_receive(:command).with("admin", ismaster: 1).and_return(info)
        node.refresh
      end

      it "does not contain duplicate nodes" do
        node.peers.size.should eq(1)
      end
    end
  end

  describe "#ensure_connected" do

    context "when the node is running" do

      it "processes the block" do
        node.ensure_connected do
          node.command("admin", ping: 1)
        end.should eq("ok" => 1)
      end
    end

    context "when the node is not running" do

      before do
        replica_set_node.stop
      end

      it "raises a connection error" do
        lambda do
          node.ensure_connected do
            node.command("admin", ping: 1)
          end
        end.should raise_exception(Moped::Errors::ConnectionFailure)
      end

      it "marks the node as down" do
        node.ensure_connected {} rescue nil
        node.should be_down
      end
    end

    context "when node is connected but connection is dropped" do

      before do
        node.ensure_connected do
          node.command("admin", ping: 1)
        end

        replica_set_node.hiccup
      end

      it "reconnects without raising an exception" do
        node.ensure_connected do
          node.command("admin", ping: 1)
        end.should eq("ok" => 1)
      end
    end

    context "when the server crashes or responds with nil" do

      it "fails over to the next node" do
        replica_set_node.crash_on_next_message!
        node.ensure_connected do
          node.command("admin", ping: 1)
        end.should eq("ok" => 1)
      end
    end

    context "when node closes the connection before sending a reply" do

      it "fails over to the next node" do
        replica_set_node.hiccup_on_next_message!
        node.ensure_connected do
          node.command("admin", ping: 1)
        end.should eq("ok" => 1)
      end
    end

    context "when the socket gets disconnected in the middle of a send" do

      before do
        Moped::Node.__send__(:public, :connection)
      end

      it "reconnects the socket" do
        node.connection.stub(:connected?).and_return(true)
        node.connection.instance_variable_set(:@sock, nil)
        lambda do
          node.ensure_connected do
            node.command("admin", ping: 1)
          end
        end.should_not raise_exception
      end
    end

    context "when there is a reconfiguration" do

      let(:potential_reconfiguration_error) do
        Moped::Errors::PotentialReconfiguration.new("", {})
      end

      before do
        node.stub(:connect).and_raise(potential_reconfiguration_error)
      end

      context "and the reconfigation is of a replica set" do

        before do
          potential_reconfiguration_error.stub(:reconfiguring_replica_set?).and_return(true)
        end

        it "raises a ReplicaSetReconfigured error" do
          expect {
            node.ensure_connected {}
          }.to raise_error(Moped::Errors::ReplicaSetReconfigured)
        end
      end

      context "and the reconfigation is not of a replica set" do

        before do
          potential_reconfiguration_error.stub(:reconfiguring_replica_set?).and_return(false)
        end

        it "raises a PotentialReconfiguration error" do
          expect {
            node.ensure_connected {}
          }.to raise_error(Moped::Errors::PotentialReconfiguration)
        end
      end
    end
  end

  describe "#initialize" do

    let(:node) do
      described_class.new("iamnota.mongoid.org")
    end

    let(:non_default_node) do
      described_class.new("iama.mongoid.org:5309")
    end

    context "defaults" do
      it("defaults to port 27017") { node.port.should eq(27017) }
    end

    context "non-default" do
      it("accepts explicit port") { non_default_node.port.should eq(5309) }
    end

    context "when dns cannot resolve the address" do

      it "flags the node as being down" do
        node.should be_down
      end

      it "sets the down_at time" do
        node.down_at.should be_within(1).of(Time.now)
      end

      context "when attempting to refresh the node" do

        before do
          node.refresh
        end

        it "keeps the node flagged as down" do
          node.should be_down
        end

        it "updates the down_at time" do
          node.down_at.should be_within(1).of(Time.now)
        end
      end
    end
  end

  describe "#refresh" do

    context "when the ismaster command fails" do

      let(:node) do
        described_class.new("127.0.0.1:27017")
      end

      before do
        node.should_receive(:command).with("admin", ismaster: 1).and_raise(Timeout::Error)
        node.refresh
      end

      it "still sets the refresh time" do
        expect(node.refreshed_at).to_not be_nil
      end
    end

    context "when the node has authentication details" do

      let(:node) do
        described_class.new("127.0.0.1:27017")
      end

      before do
        node.send(:auth)["moped_test"] = [ "user", "pass" ]
      end

      context "when discovering a peer" do

        let(:info) do
          {
            "ismaster" => true,
            "secondary" => false,
            "hosts" => [ "127.0.0.1:27017", "127.0.0.1:27018" ],
            "me" => "127.0.0.1:27017",
            "maxBsonObjectSize" => 16777216,
            "ok" => 1.0
          }
        end

        before do
          node.should_receive(:command).with("admin", ismaster: 1).and_return(info)
          node.refresh
        end

        let(:peer) do
          node.peers.last
        end

        it "add the authentication details to the peer" do
          peer.send(:auth).should eq(node.send(:auth))
        end
      end
    end

    context "when refreshing a node with a bad address" do

      let(:node) do
        described_class.new("iamnota.mongoid.org")
      end

      before do
        node.stub(:resolve_address).and_return(true)
      end

      context "when ensuring primary" do

        before do
          Moped::Threaded.stub(:executing?).with(:ensure_primary).and_return(true)
        end

        context "and not on the primary" do

          before do
            node.stub(:command).and_return("secondary" => true)
          end

          it "raises a ReplicaSetReconfigured error" do
            expect {
              node.refresh
            }.to raise_error(Moped::Errors::ReplicaSetReconfigured)
          end
        end
      end
    end
  end
end
