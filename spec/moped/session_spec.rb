require "spec_helper"

describe Moped::Session do

  let(:session) do
    Moped::Session.new(%w[127.0.0.1:27017], database: "moped_test")
  end

  before do
    session[:users].insert({ name: "test" })
    session[:users].find.remove_all
  end

  describe ".connect" do

    let(:from_uri) do
      described_class.connect("mongodb://localhost:27017/moped_test?safe=true")
    end

    it "returns the session with the correct database" do
      from_uri.__send__(:current_database).name.should eq("moped_test")
    end

    it "sets the options" do
      from_uri.options[:safe].should be_true
    end
  end

  describe "#database_names" do

    let(:names) do
      session.database_names
    end

    let(:command) do
      session.with(database: :admin).command(listDatabases: 1)
    end

    it "returns a list of all database names" do
      names.should include("moped_test")
    end
  end

  describe "#databases" do

    let(:databases) do
      session.databases
    end

    let(:command) do
      session.with(database: :admin).command(listDatabases: 1)
    end

    it "returns a list of all databases" do
      databases.should eq(command)
    end
  end

  describe "#disconnect" do

    let!(:disconnected) do
      session.disconnect
    end

    it "disconnects from the cluster" do
      session.cluster.nodes.each do |node|
        node.should_not be_connected
      end
    end

    it "returns true" do
      disconnected.should be_true
    end
  end

  describe "#drop" do

    it "drops the current database" do
      session.with(database: "moped_test_2") do |session|
        session.drop.should eq("dropped" => "moped_test_2", "ok" => 1)
      end
    end
  end

  describe "#command" do

    it "runs the command on the current database" do
      session.with(database: "moped_test_2") do |session|
        session.command(dbStats: 1)["db"].should eq "moped_test_2"
      end
    end
  end

  describe "#new" do

    it "returns a thread-safe session" do
      session.command ping: 1

      5.times.map do
        Thread.new do
          session.new do |new_session|
            new_session.command(ping: 1)
          end
        end
      end.each(&:join)
    end
  end

  describe "#read_preference" do

    context "when a read option is provided" do

      let(:secondary) do
        described_class.new([ "127.0.0.1:27017" ], read: :secondary)
      end

      it "returns the corresponding read preference" do
        expect(secondary.read_preference).to be_a(Moped::ReadPreference::Secondary)
      end
    end

    context "when no read option is provided" do

      let(:primary) do
        described_class.new([ "127.0.0.1:27017" ])
      end

      it "returns the primary read preference" do
        expect(primary.read_preference).to be_a(Moped::ReadPreference::Primary)
      end
    end
  end

  describe "#use" do

    after do
      session.use "moped_test"
    end

    it "changes the current database" do
      session.use "moped_test_2"
      session.command(dbStats: 1)["db"].should eq "moped_test_2"
    end
  end

  describe "#with" do

    context "when called with a block" do

      it "returns the value from the block" do
        session.with { :value }.should eq :value
      end

      it "yields a session with the provided options" do
        session.with(safe: true) do |safe|
          safe.options[:safe].should eq true
        end
      end

      it "does not modify the original session" do
        session.with(database: "other") do |safe|
          session.options[:database].should eq "moped_test"
        end
      end
    end

    context "when called without a block" do

      context "when changing safe mode options" do

        let(:safe) do
          session.with(safe: true)
        end

        it "returns a session with the provided options" do
          expect(safe.options[:safe]).to eq(true)
        end
      end

      context "when changing database options" do

        before do
          session.with(database: "other")
        end

        it "does not modify the original session" do
          expect(session.options[:database]).to eq("moped_test")
        end
      end

      context "when changing a read preference" do

        before do
          session.read_preference
        end

        let!(:second) do
          session.with(read: "secondary")
        end

        it "changes the read preference in the new session" do
          expect(second.read_preference).to be_a(Moped::ReadPreference::Secondary)
        end

        it "does not modify the original session" do
          expect(session.read_preference).to be_a(Moped::ReadPreference::Primary)
        end
      end

      context "when changing a write concern" do

        before do
          session.write_concern
        end

        let!(:unverify) do
          session.with(write: "unverified")
        end

        it "changes the write concern in the new session" do
          expect(unverify.write_concern).to be_a(Moped::WriteConcern::Unverified)
        end

        it "does not modify the original session" do
          expect(session.write_concern).to be_a(Moped::WriteConcern::Propagate)
        end
      end
    end
  end

  describe "#write_concern" do

    context "when a write option is provided" do

      let(:unverified) do
        described_class.new([ "127.0.0.1:27017" ], write: :unverified)
      end

      it "returns the corresponding write concern" do
        expect(unverified.write_concern).to be_a(Moped::WriteConcern::Unverified)
      end
    end

    context "when no write option is provided" do

      let(:propagate) do
        described_class.new([ "127.0.0.1:27017" ])
      end

      it "returns the propagate write concern" do
        expect(propagate.write_concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end
  end

  context "when attempting to connect to a node that does not exist" do

    let!(:session_with_bad_node) do
      Moped::Session.new(
        [ "127.0.0.1:27017", "127.0.0.1:27018" ],
        database: "moped_test"
      )
    end

    let(:nodes) do
      session_with_bad_node.cluster.seeds
    end

    it "flags the node as down" do
      session_with_bad_node.cluster.nodes
      nodes.last.should be_down
    end
  end
end
