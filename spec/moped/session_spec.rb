require "spec_helper"

describe Moped::Session do
  let(:seeds) { "127.0.0.1:27017" }
  let(:options) { Hash[database: "test", safe: true, consistency: :eventual] }
  let(:session) { described_class.new seeds, options }

  describe "#initialize" do
    it "stores the options provided" do
      session.options.should eq options
    end

    it "stores the cluster" do
      session.cluster.should be_a Moped::Cluster
    end
  end

  describe "#current_database" do
    context "when no database option has been set" do
      let(:session) { described_class.new seeds, {} }

      it "raises an exception" do
        lambda { session.current_database }.should raise_exception
      end
    end

    it "returns the database from the options" do
      database = stub
      Moped::Database.should_receive(:new).
        with(session, options[:database]).and_return(database)

      session.current_database.should eq database
    end

    it "memoizes the database" do
      database = session.current_database

      session.current_database.should eql database
    end
  end

  describe "#safe?" do
    context "when :safe is not present" do
      before do
        session.options.delete(:safe)
      end

      it "returns false" do
        session.should_not be_safe
      end
    end

    context "when :safe is present but false" do
      before do
        session.options[:safe] = false
      end

      it "returns false" do
        session.should_not be_safe
      end
    end

    context "when :safe is true" do
      before do
        session.options[:safe] = true
      end

      it "returns true" do
        session.should be_safe
      end
    end

    context "when :safe is a hash" do
      before do
        session.options[:safe] = { fsync: true }
      end

      it "returns true" do
        session.should be_safe
      end
    end
  end

  describe "#use" do
    it "sets the :database option" do
      session.use :admin
      session.options[:database].should eq :admin
    end

    context "when there is not already a current database" do
      it "sets the current database" do
        session.should_receive(:set_current_database).with(:admin)
        session.use :admin
      end
    end
  end

  describe "#with" do
    let(:new_options) { Hash[database: "test-2"] }

    context "when called with a block" do
      it "yields a session" do
        session.with(new_options) do |new_session|
          new_session.should be_a Moped::Session
        end
      end

      it "yields a new session" do
        session.with(new_options) do |new_session|
          new_session.should_not eql session
        end
      end

      it "returns the result of the block" do
        session.with(new_options) { false }.should eq false
      end

      it "merges the old and new session's options" do
        session.with(new_options) do |new_session|
          new_session.options.should eq options.merge(new_options)
        end
      end

      it "does not change the original session's options" do
        original_options = options.dup
        session.with(new_options) do |new_session|
          session.options.should eql original_options
        end
      end

      it "unmemoizes the current database" do
        db = session.current_database
        session.with(new_options) do |new_session|
          new_session.current_database.should_not eql db
        end
      end
    end

    context "when called without a block" do
      it "returns a session" do
        session.with(new_options).should be_a Moped::Session
      end

      it "returns a new session" do
        session.with(new_options).should_not eql session
      end

      it "merges the old and new session's options" do
        session.with(new_options).options.should eq options.merge(new_options)
      end

      it "does not change the original session's options" do
        original_options = options.dup
        session.with(new_options)
        session.options.should eql original_options
      end
    end
  end

  describe "#new" do
    let(:new_options) { Hash[database: "test-2"] }
    let(:new_session) { described_class.new seeds, options }

    before do
      new_session.cluster.stub(:reconnect)
    end

    it "delegates to #with" do
      session.should_receive(:with).with(new_options).and_return(new_session)
      session.new(new_options)
    end

    it "instructs the cluster to reconnect" do
      session.stub(with: new_session)
      new_session.cluster.should_receive(:reconnect)
      session.new(new_options)
    end

    context "when called with a block" do
      it "yields the new session" do
        session.stub(with: new_session)
        session.new(new_options) do |session|
          session.should eql new_session
        end
      end
    end

    context "when called without a block" do
      it "returns the new session" do
        session.stub(with: new_session)
        session.new(new_options).should eql new_session
      end
    end
  end

  describe "#drop" do
    it "delegates to the current database" do
      database = mock(Moped::Database)
      session.should_receive(:current_database).and_return(database)
      database.should_receive(:drop)

      session.drop
    end
  end

  describe "#command" do
    let(:command) { Hash[ismaster: 1] }

    it "delegates to the current database" do
      database = mock(Moped::Database)
      session.should_receive(:current_database).and_return(database)
      database.should_receive(:command).with(command)

      session.command command
    end
  end

  describe "#socket_for" do
    it "delegates to the cluster" do
      session.cluster.should_receive(:socket_for).
        with(:read)

      session.send(:socket_for, :read)
    end

    context "when retain socket option is set" do
      before do
        session.options[:retain_socket] = true
      end

      it "only aquires the socket once" do
        session.cluster.should_receive(:socket_for).
          with(:read).once.and_return(mock(Moped::Socket))

        session.send(:socket_for, :read)
        session.send(:socket_for, :read)
      end
    end
  end

  describe "#simple_query" do
    let(:query) { Moped::Protocol::Query.allocate }
    let(:socket) { mock(Moped::Socket) }
    let(:reply) do
      Moped::Protocol::Reply.allocate.tap do |reply|
        reply.documents = [{a: 1}]
      end
    end

    before do
      session.stub(socket_for: socket)
      session.stub(query: reply)
    end

    it "limits the query" do
      session.should_receive(:query) do |query|
        query.limit.should eq -1

        reply
      end

      session.simple_query(query)
    end

    it "returns the document" do
      session.simple_query(query).should eq(a: 1)
    end
  end

  describe "#query" do
    let(:query) { Moped::Protocol::Query.allocate }
    let(:socket) { mock(Moped::Socket) }
    let(:reply) do
      Moped::Protocol::Reply.allocate.tap do |reply|
        reply.documents = [{a: 1}]
      end
    end

    before do
      session.stub(socket_for: socket)
      socket.stub(:execute).and_return(reply)
    end

    context "when consistency is strong" do
      before do
        session.options[:consistency] = :strong
      end

      it "queries the master node" do
        session.should_receive(:socket_for).with(:write).
          and_return(socket)
        session.query(query)
      end
    end

    context "when consistency is eventual" do
      before do
        session.options[:consistency] = :eventual
      end

      it "queries a slave node" do
        session.should_receive(:socket_for).with(:read).
          and_return(socket)
        session.query(query)
      end

      context "and query accepts flags" do
        it "sets slave_ok on the query flags" do
          session.stub(socket_for: socket)
          socket.should_receive(:execute) do |query|
            query.flags.should include :slave_ok
          end

          session.query(query)
        end
      end

      context "and query does not accept flags" do
        let(:query) { Moped::Protocol::GetMore.allocate }

        it "doesn't try to set flags" do
          session.stub(socket_for: socket)
          lambda { session.query(query) }.should_not raise_exception
        end
      end
    end

    context "when reply has :query_failure flag" do
      before do
        reply.flags = [:query_failure]
      end

      it "raises a QueryFailure exception" do
        lambda do
          session.query(query)
        end.should raise_exception(Moped::Errors::QueryFailure)
      end
    end
  end

  describe "#execute" do
    let(:operation) { Moped::Protocol::Insert.allocate }
    let(:socket) { mock(Moped::Socket) }

    context "when session is not in safe mode" do
      before do
        session.options[:safe] = false
      end

      context "when consistency is strong" do
        before do
          session.options[:consistency] = :strong
        end

        it "executes the operation on the master node" do
          session.should_receive(:socket_for).with(:write).
            and_return(socket)
          socket.should_receive(:execute).with(operation)

          session.execute(operation)
        end
      end

      context "when consistency is eventual" do
        before do
          session.options[:consistency] = :eventual
        end

        it "executes the operation on a slave node" do
          session.should_receive(:socket_for).with(:read).
            and_return(socket)
          socket.should_receive(:execute).with(operation)

          session.execute(operation)
        end
      end
    end

    context "when session is in safe mode" do

      let(:reply) do
        Moped::Protocol::Reply.allocate.tap do |reply|
          reply.documents = [{a: 1}]
        end
      end

      before do
        session.options[:safe] = { w: 2 }
      end

      context "when the operation fails" do
        let(:reply) do
          Moped::Protocol::Reply.allocate.tap do |reply|
            reply.documents = [{
              "err"=>"document to insert can't have $ fields",
             "code"=>13511,
             "n"=>0,
             "connectionId"=>894,
             "ok"=>1.0
            }]
          end
        end

        it "raises an OperationFailure exception" do
          session.stub(socket_for: socket)
          socket.stub(execute: reply)

          lambda do
            session.execute(operation)
          end.should raise_exception(Moped::Errors::OperationFailure)
        end
      end

      context "when consistency is strong" do
        before do
          session.options[:consistency] = :strong
        end

        it "executes the operation on the master node" do
          session.should_receive(:socket_for).with(:write).
            and_return(socket)

          socket.should_receive(:execute) do |op, query|
            op.should eq operation
            query.selector.should eq(getlasterror: 1, w: 2)
            reply
          end

          session.execute(operation)
        end
      end

      context "when consistency is eventual" do
        before do
          session.options[:consistency] = :eventual
        end

        it "executes the operation on a slave node" do
          session.should_receive(:socket_for).with(:read).
            and_return(socket)

          socket.should_receive(:execute) do |op, query|
            op.should eq operation
            query.selector.should eq(getlasterror: 1, w: 2)
            reply
          end

          session.execute(operation)
        end
      end
    end
  end
end
