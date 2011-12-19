require "spec_helper"

describe Moped::Session do
  let(:seeds) { "127.0.0.1:27017" }
  let(:options) { Hash[database: "test", safe: true] }
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
    it "runs the given command against the master connection" do
      socket = mock(Moped::Socket)
      session.should_receive(:socket_for).with(:write).and_return(socket)
      socket.should_receive(:simple_query) do |query|
        query.full_collection_name.should eq "admin.$cmd"
        query.selector.should eq(ismaster: 1)
      end

      database.command ismaster: 1
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
  let(:socket) { mock(Moped::Socket) }
  let(:session) { mock(Moped::Session) }
  let(:database) { mock(Moped::Database, session: session, name: "moped") }
  let(:collection) { described_class.new database, :users }

  before do
    session.stub(socket_for: socket)
  end

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

  describe "#insert" do
    context "when passed a single document" do
      it "inserts the document" do
        socket.should_receive(:execute).with do |insert|
          insert.documents.should eq [{a: 1}]
        end
        collection.insert(a: 1)
      end
    end

    context "when passed multiple documents" do
      it "inserts the documents" do
        socket.should_receive(:execute).with do |insert|
          insert.documents.should eq [{a: 1}, {b: 2}]
        end
        collection.insert([{a: 1}, {b: 2}])
      end
    end
  end
end
