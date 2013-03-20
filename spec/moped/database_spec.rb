require "spec_helper"

describe Moped::Database do

  describe "#[]" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test")
    end

    let(:database) do
      described_class.new(session, :moped_test)
    end

    it "returns a collection for the provided name" do
      expect(database[:users].name).to eq("users")
    end

    it "returns a collection instance" do
      expect(database[:users]).to be_a(Moped::Collection)
    end
  end

  describe "#collections" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test")
    end

    let(:database) do
      described_class.new(session, :moped_test)
    end

    before do
      session.drop
      session.command(create: "users")
    end

    it "returns all the collections in the database" do
      expect(database.collections.size).to eq(1)
    end

    it "returns collection instances" do
      expect(database.collections.first.name).to eq("users")
    end
  end

  describe "#collection_names" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: "moped_test")
    end

    let(:database) do
      described_class.new(session, :moped_test)
    end

    let(:collection_names) do
      database.collection_names
    end

    before do
      session.drop
      names.map do |name|
        session.command(create: name)
      end
    end

    context "when name doesn't include system" do

      let(:names) do
        %w[ users comments ]
      end

      it "returns the name of all non system collections" do
        expect(collection_names.sort).to eq([ "comments", "users" ])
      end
    end

    context "when name includes system not at the beginning" do

      let(:names) do
        %w[ users comments_system_fu ]
      end

      it "returns the name of all non system collections" do
        expect(collection_names.sort).to eq([ "comments_system_fu", "users" ])
      end
    end

    context "when name includes system at the beginning" do

      let(:names) do
        %w[ users system_comments_fu ]
      end

      it "returns the name of all non system collections" do
        expect(collection_names.sort).to eq([ "system_comments_fu", "users" ])
      end
    end
  end

  describe "#command" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ])
    end

    let(:database) do
      described_class.new(session, :moped_test)
    end

    let(:result) do
      database.command(ping: 1)
    end

    it "executes the command on the database" do
      expect(result).to eq({ "ok" => 1.0 })
    end
  end

  describe "#drop" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ], database: :moped_new)
    end

    let(:database) do
      described_class.new(session, :moped_new)
    end

    let(:result) do
      database.drop
    end

    it "executes the command on the database" do
      expect(result).to eq({ "dropped" => "moped_new", "ok" => 1.0 })
    end
  end

  describe "#initialize" do

    let(:session) do
      Moped::Session.new([ "127.0.0.1:27017" ])
    end

    let(:database) do
      described_class.new(session, :moped_test)
    end

    it "sets the name" do
      expect(database.name).to eq("moped_test")
    end

    it "sets the session" do
      expect(database.session).to eq(session)
    end
  end
end
