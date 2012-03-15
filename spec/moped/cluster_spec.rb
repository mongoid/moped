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
    let(:cluster) do
      Moped::Cluster.new(["127.0.0.1:27017","127.0.0.1:27018"], true)
    end

    it "stores the list of seeds" do
      cluster.seeds.should eq ["127.0.0.1:27017", "127.0.0.1:27018"]
    end

    it "stores whether the connection is direct" do
      cluster.direct.should be_true
    end

    it "has an empty list of primaries" do
      cluster.primaries.should be_empty
    end

    it "has an empty list of secondaries" do
      cluster.secondaries.should be_empty
    end

    it "has an empty list of servers" do
      cluster.servers.should be_empty
    end

    it "has an empty list of dynamic seeds" do
      cluster.dynamic_seeds.should be_empty
    end
  end

  describe "#sync" do
    let(:cluster) { Moped::Cluster.new(["127.0.0.1:27017"]) }

    it "syncs each seed node" do
      server = Moped::Server.allocate
      Moped::Server.should_receive(:new).with("127.0.0.1:27017").and_return(server)

      cluster.should_receive(:sync_server).with(server).and_return([])
      cluster.sync
    end
  end

  describe "#sync_server" do
    let(:cluster) { Moped::Cluster.new [""], false }
    let(:server) { Moped::Server.new("localhost:27017") }
    let(:socket) { Moped::Socket.new "", 99999 }
    let(:connection) { Support::MockConnection.new }

    before do
      socket.stub(connection: connection, alive?: true)
      server.stub(socket: socket)
    end

    context "when node is not running" do
      it "returns nothing" do
        socket.stub(connect: false)

        cluster.sync_server(server).should be_empty
      end
    end

    context "when talking to a single node" do
      before do
        connection.pending_replies << Hash[
          "ismaster" => true,
          "maxBsonObjectSize" => 16777216,
          "ok" => 1.0
        ]
      end

      it "adds the node to the master set" do
        cluster.sync_server server
        cluster.primaries.should include server
      end
    end

    context "when talking to a replica set node" do

      context "that is not configured" do
        before do
          connection.pending_replies << Hash[
            "ismaster" => false,
            "secondary" => false,
            "info" => "can't get local.system.replset config from self or any seed (EMPTYCONFIG)",
            "isreplicaset" => true,
            "maxBsonObjectSize" => 16777216,
            "ok" => 1.0
          ]
        end

        it "returns nothing" do
          cluster.sync_server(server).should be_empty
        end
      end

      context "that is being initiated" do
        before do
          connection.pending_replies << Hash[
            "ismaster" => false,
            "secondary" => false,
            "info" => "Received replSetInitiate - should come online shortly.",
            "isreplicaset" => true,
            "maxBsonObjectSize" => 16777216,
            "ok" => 1.0
          ]
        end

        it "raises a connection failure exception" do
          cluster.sync_server(server).should be_empty
        end
      end

      context "that is ready but not elected" do
        before do
          connection.pending_replies << Hash[
            "setName" => "3fef4842b608",
            "ismaster" => false,
            "secondary" => false,
            "hosts" => ["localhost:61085", "localhost:61086", "localhost:61084"],
            "primary" => "localhost:61084",
            "me" => "localhost:61085",
            "maxBsonObjectSize" => 16777216,
            "ok" => 1.0
          ]
        end

        it "raises no exception" do
          lambda do
            cluster.sync_server server
          end.should_not raise_exception
        end

        it "adds the server to the list" do
          cluster.sync_server server
          cluster.servers.should include server
        end

        it "returns all other known hosts" do
          cluster.sync_server(server).should =~ ["localhost:61085", "localhost:61086", "localhost:61084"]
        end
      end

      context "that is ready" do
        before do
          connection.pending_replies << Hash[
            "setName" => "3ff029114780",
            "ismaster" => true,
            "secondary" => false,
            "hosts" => ["localhost:59246", "localhost:59248", "localhost:59247"],
            "primary" => "localhost:59246",
            "me" => "localhost:59246",
            "maxBsonObjectSize" => 16777216,
            "ok" => 1.0
          ]
        end

        it "adds the node to the master set" do
          cluster.sync_server server
          cluster.primaries.should include server
        end

        it "returns all other known hosts" do
          cluster.sync_server(server).should =~ ["localhost:59246", "localhost:59248", "localhost:59247"]
        end
      end

    end
  end

  describe "#socket_for" do
    let(:cluster) do
      Moped::Cluster.new ""
    end

    let(:server) do
      Moped::Server.new("localhost:27017").tap do |server|
        server.stub(socket: socket)
      end
    end

    let(:socket) do
      Moped::Socket.new("127.0.0.1", 27017).tap do |socket|
        socket.connect
      end
    end

    context "when socket is dead" do
      let(:dead_server) do
        Moped::Server.allocate.tap do |server|
          server.stub(socket: dead_socket)
        end
      end

      let(:dead_socket) do
        Moped::Socket.new("127.0.0.1", 27017).tap do |socket|
          socket.stub(:alive? => false)
        end
      end

      before do
        primaries = [server, dead_server]
        primaries.stub(:sample).and_return(dead_server, server)
        cluster.stub(primaries: primaries)
      end

      it "removes the socket" do
        cluster.should_receive(:remove).with(dead_server)
        cluster.socket_for :write
      end

      it "returns the living socket" do
        cluster.socket_for(:write).should eq socket
      end
    end

    context "when mode is write" do
      before do
        server.primary = true
      end

      context "and the cluster is not synced" do
        it "syncs the cluster" do
          cluster.should_receive(:sync) do
            cluster.servers << server
          end
          cluster.socket_for :write
        end

        it "returns the socket" do
          cluster.stub(:sync) { cluster.servers << server }
          cluster.socket_for(:write).should eq socket
        end

        it "applies the cached authentication" do
          cluster.stub(:sync) { cluster.servers << server }
          socket.should_receive(:apply_auth).with(cluster.auth)
          cluster.socket_for(:write)
        end
      end

      context "and the cluster is synced" do
        before do
          cluster.servers << server
        end

        it "does not re-sync the cluster" do
          cluster.should_receive(:sync).never
          cluster.socket_for :write
        end

        it "returns the socket" do
          cluster.socket_for(:write).should eq socket
        end

        it "applies the cached authentication" do
          socket.should_receive(:apply_auth).with(cluster.auth)
          cluster.socket_for(:write)
        end
      end
    end

    context "when mode is read" do
      context "and the cluster is not synced" do
        before do
          server.primary = true
        end

        it "syncs the cluster" do
          cluster.should_receive(:sync) do
            cluster.servers << server
          end
          cluster.socket_for :read
        end

        it "applies the cached authentication" do
          cluster.stub(:sync) { cluster.servers << server }
          socket.should_receive(:apply_auth).with(cluster.auth)
          cluster.socket_for(:read)
        end
      end

      context "and the cluster is synced" do
        context "and no secondaries are found" do
          before do
            server.primary = true
            cluster.servers << server
          end

          it "returns the master connection" do
            cluster.socket_for(:read).should eq socket
          end

          it "applies the cached authentication" do
            socket.should_receive(:apply_auth).with(cluster.auth)
            cluster.socket_for(:read)
          end
        end

        context "and a slave is found" do
          it "returns a random slave connection" do
            secondaries = [server]
            cluster.stub(secondaries: secondaries)
            secondaries.should_receive(:sample).and_return(server)
            cluster.socket_for(:read).should eq socket
          end

          it "applies the cached authentication" do
            cluster.stub(secondaries: [server])
            socket.should_receive(:apply_auth).with(cluster.auth)
            cluster.socket_for(:read)
          end
        end
      end
    end
  end

  describe "#login" do
    let(:cluster) do
      Moped::Cluster.allocate
    end

    it "adds the credentials to the auth cache" do
      cluster.login("admin", "username", "password")
      cluster.auth.should eq("admin" => ["username", "password"])
    end
  end

  describe "#logout" do
    let(:cluster) do
      Moped::Cluster.allocate
    end

    before do
      cluster.login("admin", "username", "password")
    end

    it "removes the stored credentials" do
      cluster.logout :admin
      cluster.auth.should be_empty
    end
  end
end
