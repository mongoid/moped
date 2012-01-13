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
      socket.stub(:execute).and_return(reply)
    end

    it "limits the query" do
      socket.should_receive(:execute) do |query|
        query.limit.should eq -1

        reply
      end

      session.simple_query(query)
    end

    it "returns the document" do
      socket.stub(execute: reply)
      session.simple_query(query).should eq(a: 1)
    end

    context "when consistency is strong" do
      before do
        session.options[:consistency] = :strong
      end

      it "queries the master node" do
        session.should_receive(:socket_for).with(:write).
          and_return(socket)
        session.simple_query(query)
      end
    end

    context "when consistency is eventual" do
      before do
        session.options[:consistency] = :eventual
      end

      it "queries a slave node" do
        session.should_receive(:socket_for).with(:read).
          and_return(socket)
        session.simple_query(query)
      end
    end

    context "when reply has :query_failure flag" do
      before do
        reply.flags = [:query_failure]
      end

      it "raises a QueryFailure exception" do
        lambda do
          session.simple_query(query)
        end.should raise_exception(Moped::Errors::QueryFailure)
      end
    end
  end

  describe "#execute" do
    let(:operation) { Moped::Protocol::Insert.allocate }
    let(:socket) { mock(Moped::Socket) }

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

    context "when reply has :query_failure flag" do
      let(:reply) do
        Moped::Protocol::Reply.allocate.tap do |reply|
          reply.documents = [{a: 1}]
        end
      end

      before do
        reply.flags = [:query_failure]

        session.stub(socket_for: socket)
        socket.stub(execute: reply)
      end

      it "raises a QueryFailure exception" do
        lambda do
          session.execute(operation)
        end.should raise_exception(Moped::Errors::QueryFailure)
      end
    end
  end
end

describe Moped::Database do
  let(:session) do
    Moped::Session.new ""
  end

  let(:database) do
    Moped::Database.new(session, :admin)
  end

  describe "#initialize" do
    it "stores the session" do
      database.session.should eq session
    end

    it "stores the database name" do
      database.name.should eq :admin
    end
  end

  describe "#command" do
    before do
      session.stub(:with).and_yield(session)
    end

    it "runs the given command against the master connection" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)
      session.should_receive(:simple_query) do |query|
        query.full_collection_name.should eq "admin.$cmd"
        query.selector.should eq(ismaster: 1)

        { "ok" => 1.0 }
      end

      database.command ismaster: 1
    end

    context "when the command fails" do
      it "raises an exception" do
        session.stub(simple_query: { "ok" => 0.0 })

        lambda { database.command ismaster: 1 }.should \
          raise_exception(Moped::Errors::OperationFailure)
      end
    end
  end

  describe "#drop" do
    it "drops the database" do
      database.should_receive(:command).with(dropDatabase: 1)

      database.drop
    end
  end

  describe "#[]" do
    it "returns a collection with that name" do
      Moped::Collection.should_receive(:new).with(database, :users)
      database[:users]
    end
  end
end

describe Moped::Collection do
  let(:session) { mock(Moped::Session) }
  let(:database) { mock(Moped::Database, session: session, name: "moped") }
  let(:collection) { described_class.new database, :users }

  describe "#initialize" do
    it "stores the database" do
      collection.database.should eq database
    end

    it "stores the collection name" do
      collection.name.should eq :users
    end
  end

  describe "#drop" do
    it "drops the collection" do
      database.should_receive(:command).with(drop: :users)
      collection.drop
    end
  end

  describe "#find" do
    let(:selector) { Hash[a: 1] }
    let(:query) { mock(Moped::Query) }

    it "returns a new Query" do
      Moped::Query.should_receive(:new).
        with(collection, selector).and_return(query)
      collection.find(selector).should eq query
    end

    it "defaults to an empty selector" do
      Moped::Query.should_receive(:new).
        with(collection, {}).and_return(query)
      collection.find.should eq query
    end
  end

  describe "#insert" do
    before do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)
    end

    context "when session is not in safe mode" do
      before do
        session.stub safe?: false
      end

      context "when passed a single document" do
        it "inserts the document" do
          session.should_receive(:execute).with do |insert|
            insert.documents.should eq [{a: 1}]
          end
          collection.insert(a: 1)
        end
      end

      context "when passed multiple documents" do
        it "inserts the documents" do
          session.should_receive(:execute).with do |insert|
            insert.documents.should eq [{a: 1}, {b: 2}]
          end
          collection.insert([{a: 1}, {b: 2}])
        end
      end
    end

    context "when session is in safe mode" do
      before do
        session.stub safe?: true
        session.stub safety: true
      end

      describe "#insert" do
        it "inserts the documents and checks for errors" do
          session.should_receive(:execute).with do |insert, query|
            insert.documents.should eq [{a: 1}, {b: 2}]
          end
          session.should_receive(:simple_query).with do |query|
            query.selector.should eq(getlasterror: 1, safe: true)
          end
          collection.insert([{a: 1}, {b: 2}])
        end
      end
    end
  end
end

describe Moped::Query do
  let(:session) do
    mock(Moped::Session)
  end

  let(:database) do
    mock(
      Moped::Database,
      name: "moped",
      session: session
    )
  end

  let(:collection) do
    mock(
      Moped::Collection,
      database: database,
      name: "users"
    )
  end

  let(:selector) { Hash[a: 1] }

  let(:query) { described_class.new collection, selector }

  describe "#initialize" do
    it "stores the collection" do
      query.collection.should eq collection
    end

    it "stores the selector" do
      query.selector.should eq selector
    end
  end

  describe "#limit" do
    it "sets the query operation's limit field" do
      query.limit(5)
      query.operation.limit.should eq 5
    end

    it "returns the query" do
      query.limit(5).should eql query
    end
  end

  describe "#skip" do
    it "sets the query operation's skip field" do
      query.skip(5)
      query.operation.skip.should eq 5
    end

    it "returns the query" do
      query.skip(5).should eql query
    end
  end

  describe "#select" do
    it "sets the query operation's fields" do
      query.select(a: 1)
      query.operation.fields.should eq(a: 1)
    end

    it "returns the query" do
      query.select(a: 1).should eql query
    end
  end

  describe "#sort" do
    context "when called for the first time" do
      it "updates the selector to mongo's advanced selector" do
        query.sort(a: 1)
        query.operation.selector.should eq(
          "$query" => selector,
          "$orderby" => { a: 1 }
        )
      end
    end

    context "when called again" do
      it "changes the $orderby" do
        query.sort(a: 1)
        query.sort(a: 2)
        query.operation.selector.should eq(
          "$query" => selector,
          "$orderby" => { a: 2 }
        )
      end
    end

    it "returns the query" do
      query.sort(a: 1).should eql query
    end
  end

  describe "#one" do
    it "executes a simple query" do
      session.should_receive(:simple_query).with(query.operation)
      query.one
    end
  end

  describe "#count" do
    it "executes a count command" do
      database.should_receive(:command).with(
        count: collection.name,
        query: selector
      ).and_return("n" => 4)

      query.count
    end

    it "returns the count" do
      database.stub(command: { "n" => 4 })

      query.count.should eq 4
    end
  end

  describe "#update" do
    let(:change) { Hash[a: 1] }

    it "updates the record matching selector with change" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)

      session.should_receive(:execute).with do |update|
        update.flags.should eq []
        update.selector.should eq query.operation.selector
        update.update.should eq change
      end

      query.update change
    end
  end

  describe "#update_all" do
    let(:change) { Hash[a: 1] }

    it "updates all records matching selector with change" do
      query.should_receive(:update).with(change, [:multi])
      query.update_all change
    end
  end

  describe "#upsert" do
    let(:change) { Hash[a: 1] }

    it "upserts the record matching selector with change" do
      query.should_receive(:update).with(change, [:upsert])
      query.upsert change
    end
  end

  describe "#remove" do
    it "removes the first matching document" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)

      session.should_receive(:execute).with do |delete|
        delete.flags.should eq [:remove_first]
        delete.selector.should eq query.operation.selector
      end

      query.remove
    end
  end

  describe "#remove_all" do
    it "removes all matching documents" do
      session.should_receive(:with, :consistency => :strong).
        and_yield(session)

      session.should_receive(:execute).with do |delete|
        delete.flags.should eq []
        delete.selector.should eq query.operation.selector
      end

      query.remove_all
    end
  end

  describe "#each" do
    before do
      session.should_receive(:with).
        with(retain_socket: true).and_return(session)
    end

    it "creates a new cursor" do
      cursor = mock(Moped::Cursor, next: nil)
      Moped::Cursor.should_receive(:new).
        with(session, query.operation).and_return(cursor)

      query.each
    end

    it "yields all documents in the cursor" do
      cursor = Moped::Cursor.allocate
      cursor.stub(:to_enum).and_return([1, 2].to_enum)

      Moped::Cursor.stub(new: cursor)

      query.to_a.should eq [1, 2]
    end

    it "returns an enumerator" do
      cursor = mock(Moped::Cursor)
      Moped::Cursor.stub(new: cursor)

      query.each.should be_a Enumerator
    end
  end

end
