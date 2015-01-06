require "spec_helper"

describe Moped::Cluster, replica_set: true do

  describe "#disconnect" do

    let(:cluster) do
      described_class.new(seeds, max_retries: 1, down_interval: 1)
    end

    let!(:disconnected) do
      cluster.disconnect
    end

    it "disconnects from all the nodes in the cluster" do
      cluster.nodes.each do |node|
        node.should_not be_connected
      end
    end

    it "returns true" do
      disconnected.should be_true
    end
  end

  context "when no nodes are available" do

    let(:cluster) do
      described_class.new(seeds, max_retries: 1, down_interval: 1)
    end

    before do
      @replica_set.nodes.each(&:stop)
    end

    describe "#with_primary" do

      it "raises a connection error" do
        lambda do
          cluster.with_primary do |node|
            node.command("admin", ping: 1)
          end
        end.should raise_exception(Moped::Errors::ConnectionFailure)
      end
    end

    describe "#with_secondary" do

      it "raises a connection error" do
        lambda do
          cluster.with_secondary do |node|
            node.command("admin", ping: 1)
          end
        end.should raise_exception(Moped::Errors::ConnectionFailure)
      end
    end
  end

  context "when the replica set hasn't connected yet" do

    let(:cluster) do
      described_class.new(seeds, max_retries: 1, down_interval: 1)
    end

    describe "#with_primary" do

      it "connects and yields the primary node" do
        cluster.with_primary do |node|
          node.address.original.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do

      it "connects and yields a secondary node" do
        cluster.with_secondary do |node|
          @secondaries.map(&:address).should include node.address.original
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
            cluster.with_primary do |node|
              node.command "admin", ping: 1
            end
          end.should raise_exception(Moped::Errors::ConnectionFailure)
        end
      end

      describe "#with_secondary" do

        it "connects and yields a secondary node" do
          cluster.with_secondary do |node|
            @secondaries.map(&:address).should include node.address.original
          end
        end
      end
    end

    [
      Moped::Errors::ReplicaSetReconfigured.new({}, {}),
      Moped::Errors::ConnectionFailure.new
    ].each do |ex|

      context "and a secondary raises an #{ex.class} error" do
        let(:first_node) { @secondaries.first }
        let(:second_node_address) { @secondaries[1].address }

        before :each do
          # We need to effectively stub out the shuffle! so we can deterministically check that we get the second node
          cluster.stub(:available_secondary_nodes).and_return(@secondaries.dup)
          first_node.stub(:kill_cursors).and_raise(ex)
        end

        it "connects and yields a secondary node" do
          cluster.with_secondary do |node|
            node.kill_cursors([123])
            node.address.should eq second_node_address
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
          cluster.with_primary do |node|
            node.address.original.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do

        it "connects and yields a secondary node" do
          cluster.with_secondary do |node|
            node.address.original.should eq @secondaries.last.address
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
          cluster.with_primary do |node|
            node.address.original.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do

        it "raises a connection faiure" do
          expect {
            cluster.with_secondary {}
          }.to raise_error(Moped::Errors::ConnectionFailure)
        end
      end
    end
  end

  context "when the replica set is connected" do

    let(:cluster) do
      described_class.new(seeds, max_retries: 1, down_interval: 1)
    end

    before do
      cluster.refresh
    end

    describe "#with_primary" do

      it "connects and yields the primary node" do
        cluster.with_primary do |node|
          node.address.original.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do

      it "connects and yields a secondary node" do
        cluster.with_secondary do |node|
          @secondaries.map(&:address).should include node.address.original
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
            cluster.with_primary do |node|
              node.command "admin", ping: 1
            end
          end.should raise_exception(Moped::Errors::ConnectionFailure)
        end
      end

      describe "#with_secondary" do

        it "connects and yields a secondary node" do
          cluster.with_secondary do |node|
            @secondaries.map(&:address).should include node.address.original
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
          cluster.with_primary do |node|
            node.address.original.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do

        it "connects and yields a secondary node" do
          cluster.with_secondary do |node|
            node.command "admin", ping: 1
            node.address.original.should eq @secondaries.last.address
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
          cluster.with_primary do |node|
            node.address.original.should eq @primary.address
          end
        end
      end

      describe "#with_secondary" do

        it "raises a connection failure" do
          expect {
            cluster.with_secondary do |node|
              node.command("admin", ping: 1)
            end
          }.to raise_error(Moped::Errors::ConnectionFailure)
        end
      end
    end
  end

  context "with down interval" do

    let(:cluster) do
      Moped::Cluster.new(seeds, { down_interval: 5, pool_size: 1 })
    end

    context "and all secondaries are down" do

      before do
        cluster.refresh
        @secondaries.each(&:stop)
        cluster.refresh
      end

      describe "#with_secondary" do

        it "raises a connection failure" do
          expect {
            cluster.with_secondary do |node|
              node.command("admin", ping: 1)
            end
          }.to raise_error(Moped::Errors::ConnectionFailure)
        end
      end

      context "when a secondary node comes back up" do

        before do
          @secondaries.each(&:restart)
        end

        describe "#with_secondary" do

          it "raises an error" do
            expect {
              cluster.with_secondary do |node|
                node.command "admin", ping: 1
              end
            }.to raise_error(Moped::Errors::ConnectionFailure)
          end
        end

        context "and the node is ready to be retried" do

          it "connects and yields the secondary node" do
            Time.stub(:new).and_return(Time.now + 10)
            cluster.with_secondary do |node|
              node.command "admin", ping: 1
              @secondaries.map(&:address).should include node.address.original
            end
          end
        end
      end
    end
  end

  context "with only primary provided as a seed" do

    let(:cluster) do
      Moped::Cluster.new([@primary.address], {})
    end

    describe "#with_primary" do

      it "connects and yields the primary node" do
        cluster.with_primary do |node|
          node.address.original.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do

      it "connects and yields a secondary node" do
        cluster.with_secondary do |node|
          @secondaries.map(&:address).should include node.address.original
        end
      end
    end
  end

  context "with only a secondary provided as a seed" do

    let(:cluster) do
      Moped::Cluster.new([@secondaries[0].address], {})
    end

    describe "#with_primary" do

      it "connects and yields the primary node" do
        cluster.with_primary do |node|
          node.address.original.should eq @primary.address
        end
      end
    end

    describe "#with_secondary" do

      it "connects and yields a secondary node" do
        cluster.with_secondary do |node|
          @secondaries.map(&:address).should include node.address.original
        end
      end
    end
  end

  describe "#refresh" do

    let(:cluster) do
      described_class.new(seeds, max_retries: 1, down_interval: 1)
    end

    context "when old nodes are removed from the set" do

      before do
        @secondaries.delete(@replica_set.remove_node)
        cluster.refresh
      end

      it "gets removed from the available nodes and configured nodes" do
        cluster.nodes.size.should eq(2)
        cluster.seeds.size.should eq(2)
      end
    end
  end

  describe "#refreshable?" do

    let(:cluster) do
      described_class.new(seeds, {})
    end

    context "when the node is an arbiter" do

      let(:node) do
        cluster.nodes.first
      end

      before do
        node.instance_variable_set(:@arbiter, true)
        node.instance_variable_set(:@down_at, Time.new - 60)
      end

      it "returns false" do
        expect(cluster.send(:refreshable?, node)).to be_false
      end
    end
  end
end

describe Moped::Cluster, "authentication", mongohq: :auth do

  shared_examples_for "authenticable session" do

    context "when logging in with valid credentials" do

      it "logs in and processes commands" do
        session.login(*Support::MongoHQ.auth_credentials)
        session.command(ping: 1).should eq("ok" => 1)
      end
    end

    context "when logging in with invalid credentials" do

      it "raises an AuthenticationFailure exception" do
        session.login "invalid-user", "invalid-password"

        lambda do
          session.command(ping: 1)
        end.should raise_exception(Moped::Errors::AuthenticationFailure)
      end
    end

    context "when logging in with valid credentials and then logging out" do

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

  context "when there are multiple connections on the pool" do

    let(:session) do
      Support::MongoHQ.auth_session(false)
    end

    it_behaves_like "authenticable session"
  end

  context "when there is one connections on the pool" do

    let(:session) do
      Support::MongoHQ.auth_session(false, pool_size: 1)
    end

    it_behaves_like "authenticable session"

    context "when disconnecting the session" do

      before do
        session.login(*Support::MongoHQ.auth_credentials)
        session.disconnect
      end

      it "reconnects" do
        session.command(ping: 1).should eq("ok" => 1)
      end

      it "authenticates" do
        session[:users].find.entries.should eq([])
      end
    end

    context "when creating multiple sessions" do

      before do
        session.login(*Support::MongoHQ.auth_credentials)
      end

      let(:session_two) do
        Support::MongoHQ.auth_session(true, pool_size: 1)
      end

      let(:connection) do
        conn = nil
        session.cluster.seeds.first.connection { |c| conn = c }
        conn
      end

      it "logs in only once" do
        connection.should_receive(:login).once.and_call_original
        session.command(ping: 1).should eq("ok" => 1)
        session_two.command(ping: 1).should eq("ok" => 1)
      end

      it "does not logout" do
        connection.should_receive(:logout).never
        session.command(ping: 1).should eq("ok" => 1)
        session_two.command(ping: 1).should eq("ok" => 1)
      end
    end
  end
end

describe Moped::Cluster, "after a reconfiguration" do
  let(:options) do
    {
      max_retries: 30,
      retry_interval: 1,
      timeout: 5,
      database: 'test_db',
      read: :primary,
      write: {w: 'majority'}
    }
  end

  let(:replica_set_name) { 'dev' }

  let(:session) do
    Moped::Session.new([ "127.0.0.1:31100", "127.0.0.1:31101", "127.0.0.1:31102" ], options)
  end

  def step_down_servers
    step_down_file = File.join(Dir.tmpdir, with_authentication? ? "step_down_with_authentication.js" : "step_down_without_authentication.js")
    unless File.exists?(step_down_file)
      File.open(step_down_file, "w") do |file|
        user_data = with_authentication? ? ", 'admin', 'admin_pwd'" : ""
        file.puts %{
          function stepDown(dbs) {
            for (i in dbs) {
              dbs[i].adminCommand({replSetFreeze:5});
              try { dbs[i].adminCommand({replSetStepDown:5}); } catch(e) { print(e) };
            }
          };

          var db1 = connect('localhost:31100/admin'#{user_data});
          var db2 = connect('localhost:31101/admin'#{user_data});
          var db3 = connect('localhost:31102/admin'#{user_data});

          var dbs = [db1, db2, db3];
          stepDown(dbs);

          while (db1.adminCommand({ismaster:1}).ismaster || db2.adminCommand({ismaster:1}).ismaster || db2.adminCommand({ismaster:1}).ismaster) {
            stepDown(dbs);
          }
        }
      end
    end
    system "mongo --nodb #{step_down_file} 2>&1 > /dev/null"
  end

  shared_examples_for "recover the session" do
    it "should execute commands normally before the stepDown" do
      time = Benchmark.realtime do
        session[:foo].find().remove_all()
        session[:foo].find().to_a.count.should eql(0)
        session[:foo].insert({ name: "bar 1" })
        session[:foo].find().to_a.count.should eql(1)
        expect {
          session[:foo].insert({ name: "bar 1" })
        }.to raise_exception(Moped::Errors::OperationFailure, /duplicate/)
      end
      time.should be < 2
    end

    it "should recover and execute a find" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1" })
      step_down_servers
      time = Benchmark.realtime do
        session[:foo].find().to_a.count.should eql(1)
      end
      session.cluster.nodes.map(&:refresh)
      expect{ session.cluster.nodes.any?{ |node| node.primary? } }.to be_true
      time.should be > 5
      time.should be < 29
    end

    it "should recover and execute an insert" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1" })
      step_down_servers
      time = Benchmark.realtime do
        session[:foo].insert({ name: "bar 2" })
        session[:foo].find().to_a.count.should eql(2)
      end
      time.should be > 5
      time.should be < 29

      session[:foo].insert({ name: "bar 3" })
      session[:foo].find().to_a.count.should eql(3)
    end

    it "should recover and try an insert which hit a constraint" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1" })
      step_down_servers
      time = Benchmark.realtime do
        expect {
          session[:foo].insert({ name: "bar 1" })
        }.to raise_exception(Moped::Errors::OperationFailure, /duplicate/)
      end
      session.cluster.nodes.map(&:refresh)
      expect{ session.cluster.nodes.any?{ |node| node.primary? } }.to be_true
      time.should be > 5
      time.should be < 29

      session[:foo].find().to_a.count.should eql(1)

      session[:foo].insert({ name: "bar 2" })
      session[:foo].find().to_a.count.should eql(2)
    end

    it "should recover and execute an update" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1" })
      cursor = session[:foo].find({ name: "bar 1" })
      step_down_servers
      time = Benchmark.realtime do
        cursor.update({ name: "bar 2" })
      end
      time.should be > 5
      time.should be < 29

      session[:foo].find().to_a.count.should eql(1)
      session[:foo].find({ name: "bar 1" }).to_a.count.should eql(0)
      session[:foo].find({ name: "bar 2" }).to_a.count.should eql(1)
    end

    it "should recover and execute a remove" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1", type: "some" })
      session[:foo].insert({ name: "bar 2", type: "some" })
      cursor = session[:foo].find({ type: "some" })
      step_down_servers
      time = Benchmark.realtime do
        cursor.remove()
      end
      time.should be > 5
      time.should be < 29

      session[:foo].find().to_a.count.should eql(1)
      session[:foo].find({ name: "bar 1" }).to_a.count.should eql(0)
      session[:foo].find({ name: "bar 2" }).to_a.count.should eql(1)
    end

    it "should recover and execute a remove_all" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1", type: "some" })
      session[:foo].insert({ name: "bar 2", type: "some" })
      cursor = session[:foo].find({ type: "some" })
      step_down_servers
      time = Benchmark.realtime do
        cursor.remove_all()
      end
      time.should be > 5
      time.should be < 29

      session[:foo].find().to_a.count.should eql(0)
      session[:foo].find({ name: "bar 1" }).to_a.count.should eql(0)
      session[:foo].find({ name: "bar 2" }).to_a.count.should eql(0)
    end

    it "should recover and execute an operation using the basic command method" do
      session[:foo].find().remove_all()
      session[:foo].insert({ name: "bar 1", type: "some" })
      session[:foo].insert({ name: "bar 2", type: "some" })
      cursor = session[:foo].find({ type: "some" })
      step_down_servers
      time = Benchmark.realtime do
        cursor.count.should eql(2)
      end
      time.should be > 5
      time.should be < 29
    end
  end

  describe "with authentication off" do
    before do
      setup_replicaset_environment(with_authentication?)
    end

    let(:with_authentication?) { false }

    it_should_behave_like "recover the session"
  end

  describe "with authentication on" do
    before do
      setup_replicaset_environment(with_authentication?)
      session.login('common', 'common_pwd')
    end

    let(:with_authentication?) { true }

    it_should_behave_like "recover the session"
  end
end
