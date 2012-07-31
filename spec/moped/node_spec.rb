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

  describe "#ensure_connected" do
    context "when node is running" do
      it "processes the block" do
        node.ensure_connected do
          node.command("admin", ping: 1)
        end.should eq("ok" => 1)
      end
    end

    context "when node is not running" do
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

    context "when node closes the connection before sending a reply" do
      it "raises an exception" do
        replica_set_node.hiccup_on_next_message!
        lambda do
          node.ensure_connected do
            node.command("admin", ping: 1)
          end
        end.should raise_exception(Moped::Errors::SocketError)
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
  end
end
