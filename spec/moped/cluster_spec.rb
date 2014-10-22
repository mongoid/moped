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

  def servers_status
    auth = has_user_admin? ? "-u admin -p admin_pwd --authenticationDatabase admin" : ""
    `echo 'rs.status().members[0].stateStr + "|" + rs.status().members[1].stateStr + "|" + rs.status().members[2].stateStr' | mongo --quiet --port 31100 #{auth} 2>/dev/null`.chomp.split("|")
  end

  def has_user_admin?
    auth = with_authentication? ? "-u admin -p admin_pwd --authenticationDatabase admin" : ""
    `echo 'db.getSisterDB("admin").getUser("admin").user' | mongo --quiet --port 31100 #{auth} 2>/dev/null`.chomp   == "admin"
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
        }.to raise_exception
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
        }.to raise_exception
      end
      time.should be > 5
      time.should be < 29

      session[:foo].find().to_a.count.should eql(1)

      session[:foo].insert({ name: "bar 2" })
      session[:foo].find().to_a.count.should eql(2)
    end
  end

  describe "with authentication off" do
    before do
      unless servers_status.all?{|st| st == "PRIMARY" || st == "SECONDARY"} && !has_user_admin?
        start_mongo_server(31100, "--replSet #{replica_set_name}")
        start_mongo_server(31101, "--replSet #{replica_set_name}")
        start_mongo_server(31102, "--replSet #{replica_set_name}")

        `echo "rs.initiate({_id : '#{replica_set_name}', 'members' : [{_id:0, host:'localhost:31100'},{_id:1, host:'localhost:31101'},{_id:2, host:'localhost:31102'}]})"  | mongo --port 31100`
        sleep 0.1 while !servers_status.all?{|st| st == "PRIMARY" || st == "SECONDARY"}

        master = `echo 'db.isMaster().primary' | mongo --quiet --port 31100`.chomp

        `echo "
        use test_db;
        db.foo.ensureIndex({name:1}, {unique:1});
        " | mongo #{master}`
      end
    end

    let(:with_authentication?) { false }

    it_should_behave_like "recover the session"
  end

  describe "with authentication on" do
    before do
      unless servers_status.all?{|st| st == "PRIMARY" || st == "SECONDARY"} && has_user_admin?
        keyfile = File.join(Dir.tmpdir, "31000", "keyfile")
        FileUtils.mkdir_p(File.dirname(keyfile))
        File.open(keyfile, "w") do |f| f.puts "SyrfEmAevWPEbgRZoZx9qZcZtJAAfd269da+kzi0H/7OuowGLxM3yGGUHhD379qP
nw4X8TT2T6ecx6aqJgxG+biJYVOpNK3HHU9Dp5q6Jd0bWGHGGbgFHV32/z2FFiti
EFLimW/vfn2DcJwTW29nQWhz2wN+xfMuwA6hVxFczlQlz5hIY0+a+bQChKw8wDZk
rW1OjTQ//csqPbVA8fwB49ghLGp+o84VujhRxLJ+0sbs8dKoIgmVlX2kLeHGQSf0
KmF9b8kAWRLwLneOR3ESovXpEoK0qpQb2ym6BNqP32JKyPA6Svb/smVONhjUI71f
/zQ2ETX7ylpxIzw2SMv/zOWcVHBqIbdP9Llrxb3X0EsB6J8PeI8qLjpS94FyEddw
ACMcAxbP+6BaLjXyJ2WsrEeqThAyUC3uF5YN/oQ9XiATqP7pDOTrmfn8LvryyzcB
ByrLRTPOicBaG7y13ATcCbBdrYH3BE4EeLkTUZOg7VzvRnATvDpt0wOkSnbqXow8
GQ6iMUgd2XvUCuknQLD6gWyoUyHiPADKrLsgnd3Qo9BPxYJ9VWSKB4phK3N7Bic+
BwxlcpDFzGI285GR4IjcJbRRjjywHq5XHOxrJfN+QrZ/6wy6yu2+4NTPj+BPC5iX
/dNllTEyn7V+pr6FiRv8rv8RcxJgf3nfn/Xz0t2zW2olcalEFxwKKmR20pZxPnSv
Kr6sVHEzh0mtA21LoK5G8bztXsgFgWU7hh9z8UUo7KQQnDfyPb6k4xroeeQtWBNo
TZF1pI5joLytNSEtT+BYA5wQSYm4WCbhG+j7ipcPIJw6Un4ZtAZs0aixDfVE0zo0
w2FWrYH2dmmCMbz7cEXeqvQiHh9IU/hkTrKGY95STszGGFFjhtS2TbHAn2rRoFI0
VwNxMJCC+9ZijTWBeGyQOuEupuI4C9IzA5Gz72048tpZ0qMJ9mOiH3lZFtNTg/5P
28Td2xzaujtXjRnP3aZ9z2lKytlr
"
        end

        File.chmod(0600, keyfile)

        start_mongo_server(31100, "--replSet #{replica_set_name} --keyFile #{keyfile} --auth")
        start_mongo_server(31101, "--replSet #{replica_set_name} --keyFile #{keyfile} --auth")
        start_mongo_server(31102, "--replSet #{replica_set_name} --keyFile #{keyfile} --auth")

        `echo "rs.initiate({_id : '#{replica_set_name}', 'members' : [{_id:0, host:'localhost:31100'},{_id:1, host:'localhost:31101'},{_id:2, host:'localhost:31102'}]})"  | mongo --port 31100`
        sleep 0.1 while !servers_status.all?{|st| st == "PRIMARY" || st == "SECONDARY"}

        master = `echo 'db.isMaster().primary' | mongo --quiet --port 31100`.chomp

        `echo "
        use admin;
        db.addUser('admin', 'admin_pwd');
        " | mongo #{master}`

        `echo "
        use test_db;
        db.addUser('common', 'common_pwd');
        db.foo.ensureIndex({name:1}, {unique:1});
        " | mongo #{master} -u admin -p admin_pwd --authenticationDatabase admin`
      end

      session.login('common', 'common_pwd')
    end

    let(:with_authentication?) { true }

    it_should_behave_like "recover the session"
  end
end
