require "spec_helper"

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

        expect {
          database.command ismaster: 1
        }.to raise_exception(Moped::Errors::OperationFailure)
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

  describe "#login" do

    it "logs in to the database with the username and password" do
      session.cluster.should_receive(:login).with(:admin, "username", "password")
      database.login("username", "password")
    end
  end

  describe "#log out" do

    it "logs out from the database" do
      session.cluster.should_receive(:logout).with(:admin)
      database.logout
    end
  end
end
