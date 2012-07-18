require "spec_helper"

describe Moped::Cluster, replica_set: true do

  let(:replica_set) do
    Moped::Cluster.new(seeds, {})
  end

  describe "#disconnect" do

    let!(:disconnected) do
      replica_set.disconnect
    end

    it "disconnects from all the nodes in the cluster" do
      replica_set.nodes.each do |node|
        node.should_not be_connected
      end
    end

    it "returns true" do
      disconnected.should be_true
    end
  end

  context "when no nodes are available" do
    before do
      @replica_set.nodes.each(&:stop)
    end

    describe "#with_primary" do
      it "raises a connection error" do
        lambda do
          replica_set.with_primary do |node|
            node.command("admin", ping: 1)
          end
        end.should raise_exception(Moped::Errors::ConnectionFailure)
      end
    end

    describe "#with_secondary" do
      it "raises a connection error" do
        lambda do
          replica_set.with_secondary do |node|
            node.command("admin", ping: 1)
          end
        end.should raise_exception(Moped::Errors::ConnectionFailure)
      end
    end
  end

  context "when the replica set hasn't connected yet" do
    describe "#with_primary" do
      it "connects and yields the primary node" do
        replica_set.with_primary do |node|
          node.address.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do
      it "connects and yields a secondary node" do
        replica_set.with_secondary do |node|
          @secondaries.map(&:address).should include node.address
        end
      end
    end

    context "and the primary is down" do
      before do
        @primary.stop
      end

      describe "#with_primary" do
        it "raises a connection error" do
          lambda do
            replica_set.with_primary do |node|
              node.command "admin", ping: 1
            end
          end.should raise_exception(Moped::Errors::ConnectionFailure)
        end
      end

      describe "#with_secondary" do
        it "connects and yields a secondary node" do
          replica_set.with_secondary do |node|
            @secondaries.map(&:address).should include node.address
          end
        end
      end
    end

    context "and a single secondary is down" do
      before do
        @secondaries.first.stop
      end

      describe "#with_primary" do
        it "connects and yields the primary node" do
          replica_set.with_primary do |node|
            node.address.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do
        it "connects and yields a secondary node" do
          replica_set.with_secondary do |node|
            node.address.should eq @secondaries.last.address
          end
        end
      end
    end

    context "and all secondaries are down" do
      before do
        @secondaries.each(&:stop)
      end

      describe "#with_primary" do
        it "connects and yields the primary node" do
          replica_set.with_primary do |node|
            node.address.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do
        it "connects and yields the primary node" do
          replica_set.with_secondary do |node|
            node.address.should eq @primary.address
          end
        end
      end
    end
  end

  context "when the replica set is connected" do
    before do
      replica_set.refresh
    end

    describe "#with_primary" do
      it "connects and yields the primary node" do
        replica_set.with_primary do |node|
          node.address.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do
      it "connects and yields a secondary node" do
        replica_set.with_secondary do |node|
          @secondaries.map(&:address).should include node.address
        end
      end
    end

    context "and the primary is down" do
      before do
        @primary.stop
      end

      describe "#with_primary" do
        it "raises a connection error" do
          lambda do
            replica_set.with_primary do |node|
              node.command "admin", ping: 1
            end
          end.should raise_exception(Moped::Errors::ConnectionFailure)
        end
      end

      describe "#with_secondary" do
        it "connects and yields a secondary node" do
          replica_set.with_secondary do |node|
            @secondaries.map(&:address).should include node.address
          end
        end
      end
    end

    context "and a single secondary is down" do
      before do
        @secondaries.first.stop
      end

      describe "#with_primary" do
        it "connects and yields the primary node" do
          replica_set.with_primary do |node|
            node.address.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do
        it "connects and yields a secondary node" do
          replica_set.with_secondary do |node|
            node.command "admin", ping: 1
            node.address.should eq @secondaries.last.address
          end
        end
      end
    end

    context "and all secondaries are down" do
      before do
        @secondaries.each(&:stop)
      end

      describe "#with_primary" do
        it "connects and yields the primary node" do
          replica_set.with_primary do |node|
            node.address.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do
        it "connects and yields the primary node" do
          replica_set.with_secondary do |node|
            node.command "admin", ping: 1
            node.address.should eq @primary.address
          end
        end
      end
    end
  end

  context "with down interval" do
    let(:replica_set) do
      Moped::Cluster.new(seeds, { down_interval: 5 })
    end

    context "and all secondaries are down" do
      before do
        replica_set.refresh
        @secondaries.each(&:stop)
        replica_set.refresh
      end

      describe "#with_secondary" do
        it "connects and yields the primary node" do
          replica_set.with_secondary do |node|
            node.command "admin", ping: 1
            node.address.should eq @primary.address
          end
        end
      end

      context "when a secondary node comes back up" do
        before do
          @secondaries.each(&:restart)
        end

        describe "#with_secondary" do
          it "connects and yields the primary node" do
            replica_set.with_secondary do |node|
              node.command "admin", ping: 1
              node.address.should eq @primary.address
            end
          end
        end

        context "and the node is ready to be retried" do
          it "connects and yields the secondary node" do
            Time.stub(:new).and_return(Time.now + 10)
            replica_set.with_secondary do |node|
              node.command "admin", ping: 1
              @secondaries.map(&:address).should include node.address
            end
          end
        end
      end
    end
  end

  context "with only primary provided as a seed" do
    let(:replica_set) do
      Moped::Cluster.new([@primary.address], {})
    end

    describe "#with_primary" do
      it "connects and yields the primary node" do
        replica_set.with_primary do |node|
          node.address.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do
      it "connects and yields a secondary node" do
        replica_set.with_secondary do |node|
          @secondaries.map(&:address).should include node.address
        end
      end
    end
  end

  context "with only a secondary provided as a seed" do
    let(:replica_set) do
      Moped::Cluster.new([@secondaries[0].address], {})
    end

    describe "#with_primary" do
      it "connects and yields the primary node" do
        replica_set.with_primary do |node|
          node.address.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do
      it "connects and yields a secondary node" do
        replica_set.with_secondary do |node|
          @secondaries.map(&:address).should include node.address
        end
      end
    end
  end
end

describe Moped::Cluster, "authentication", mongohq: :auth do
  let(:session) do
    Support::MongoHQ.auth_session(false)
  end

  describe "logging in with valid credentials" do
    it "logs in and processes commands" do
      session.login(*Support::MongoHQ.auth_credentials)
      session.command(ping: 1).should eq("ok" => 1)
    end
  end

  describe "logging in with invalid credentials" do
    it "raises an AuthenticationFailure exception" do
      session.login "invalid-user", "invalid-password"

      lambda do
        session.command(ping: 1)
      end.should raise_exception(Moped::Errors::AuthenticationFailure)
    end
  end

  describe "logging in with valid credentials and then logging out" do
    before do
      session.login(*Support::MongoHQ.auth_credentials)
      session.command(ping: 1).should eq("ok" => 1)
    end

    it "logs out" do
      lambda do
        session.command dbStats: 1
      end.should_not raise_exception

      session.logout

      lambda do
        session.command dbStats: 1
      end.should raise_exception(Moped::Errors::OperationFailure)
    end
  end
end
