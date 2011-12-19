require "spec_helper"

describe Moped::Cluster do

  let(:master) do
    TCPServer.new "127.0.0.1", 0
  end

  let(:secondary_1) do
    TCPServer.new "127.0.0.1", 0
  end

  let(:secondary_2) do
    TCPServer.new "127.0.0.1", 0
  end

  describe "initialize" do
    let(:cluster) { Moped::Cluster.new("127.0.0.1:27017", true) }

    it "stores the list of seeds" do
      cluster.seeds.should eq [["127.0.0.1", 27017]]
    end

    it "stores whether the connection is direct" do
      cluster.direct.should be_true
    end

    it "has an empty list of masters" do
      cluster.masters.should be_empty
    end

    it "has an empty list of slaves" do
      cluster.slaves.should be_empty
    end

    it "has an empty list of servers" do
      cluster.servers.should be_empty
    end

    it "has an empty list of dynamic seeds" do
      cluster.dynamic_seeds.should be_empty
    end
  end

  describe "#remove" do
    let(:cluster) { Moped::Cluster.new("") }
    let(:socket) { Moped::Socket.allocate }

    context "when removing a slave connection" do
      before do
        cluster.slaves << socket
        cluster.servers << socket
        cluster.remove socket
      end

      it "is removed from the list of slaves" do
        cluster.slaves.should_not include socket
      end

      it "is removed from the list of servers" do
        cluster.servers.should_not include socket
      end
    end

    context "when removing a master connection" do
      before do
        cluster.masters << socket
        cluster.servers << socket
        cluster.remove socket
      end

      it "is removed from the list of masters" do
        cluster.masters.should_not include socket
      end

      it "is removed from the list of servers" do
        cluster.servers.should_not include socket
      end
    end
  end

  describe "#sync" do
    let(:cluster) { Moped::Cluster.new("127.0.0.1:27017") }

    it "syncs each seed node" do
      socket = stub
      Moped::Socket.should_receive(:new).with("127.0.0.1", 27017).
        and_return(socket)

      cluster.should_receive(:sync_socket).with(socket)
      cluster.sync
    end
  end

  describe "#sync_socket" do
    let(:cluster) { Moped::Cluster.new("127.0.0.1:27017") }
    let(:socket) { Moped::Socket.new("127.0.0.1", 27017) }

    before do
      socket.stub :connect
      socket.stub :close
    end

    context "when socket is a master connection" do
      before do
        socket.stub(simple_query: { "ismaster" => true })
      end

      it "adds it to the list of servers" do
        cluster.sync_socket socket
        cluster.servers.should include socket
      end

      it "adds it to the list of masters" do
        cluster.sync_socket socket
        cluster.masters.should include socket
      end
    end

    context "when socket is a secondary connection" do
      before do
        socket.stub(simple_query: { "secondary" => true })
      end

      it "adds it to the list of servers" do
        cluster.sync_socket socket
        cluster.servers.should include socket
      end

      it "adds it to the list of slaves" do
        cluster.sync_socket socket
        cluster.slaves.should include socket
      end
    end

    context "when socket is a passive connection" do
      before do
        socket.stub(simple_query: { "passive" => true })
      end

      it "does not add it to the list of servers" do
        cluster.sync_socket socket
        cluster.servers.should_not include socket
      end

      it "closes the socket" do
        socket.should_receive(:close)
        cluster.sync_socket socket
      end
    end
  end

  describe "#socket_for" do
    let(:cluster) do
      Moped::Cluster.new ""
    end

    let(:socket) do
      Moped::Socket.new("127.0.0.1", 27017).tap do |socket|
        socket.connect
      end
    end

    context "when socket is dead" do
      let(:dead_socket) do
        Moped::Socket.new("127.0.0.1", 27017).tap do |socket|
          socket.stub(:dead? => true)
        end
      end

      before do
        cluster.masters << socket
        cluster.masters << dead_socket
        cluster.masters.stub(:sample).and_return(dead_socket, socket)
      end

      it "removes the socket" do
        cluster.should_receive(:remove).with(dead_socket)
        cluster.socket_for :write
      end

      it "returns the living socket" do
        cluster.socket_for(:write).should eq socket
      end
    end

    context "when mode is write" do
      context "and the cluster is not synced" do
        it "syncs the cluster" do
          cluster.should_receive(:sync) do
            cluster.masters << socket
          end
          cluster.socket_for :write
        end

        it "returns the socket" do
          cluster.stub(:sync) do
            cluster.masters << socket
          end
          cluster.socket_for(:write).should eq socket
        end
      end

      context "and the cluster is synced" do
        before do
          cluster.masters << socket
        end

        it "does not re-sync the cluster" do
          cluster.should_receive(:sync).never
          cluster.socket_for :write
        end

        it "returns the socket" do
          cluster.socket_for(:write).should eq socket
        end
      end
    end

    context "when mode is read" do
      context "and the cluster is not synced" do
        it "syncs the cluster" do
          cluster.should_receive(:sync) do
            cluster.masters << socket
          end
          cluster.socket_for :read
        end
      end

      context "and the cluster is synced" do
        context "and no slaves are found" do
          before do
            cluster.masters << socket
          end

          it "returns the master connection" do
            cluster.socket_for(:read).should eq socket
          end
        end

        context "and a slave is found" do
          before do
            cluster.slaves << socket
          end

          it "returns a random slave connection" do
            cluster.slaves.should_receive(:sample).and_return(socket)
            cluster.socket_for(:read).should eq socket
          end
        end
      end
    end
  end
end
