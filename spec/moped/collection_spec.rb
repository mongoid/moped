require "spec_helper"

describe Moped::Collection do
  let(:session) do
    Moped::Session.new %w[127.0.0.1:27017], database: "moped_test"
  end

  let(:scope) { object_id }

  describe "#drop" do
    context "when collection exists" do
      before do
        session.drop
        session.command create: "users"
      end

      it "drops the collection" do
        result = session[:users].drop
        result["ns"].should eq "moped_test.users"
      end
    end

    context "when collection doesn't exist" do
      before do
        session.drop
      end

      it "works" do
        session[:users].drop.should be_false
      end
    end
  end

  describe "#insert" do

    it "inserts a single document" do
      document = { "_id" => Moped::BSON::ObjectId.new, "scope" => scope }
      session[:users].insert(document)
      session[:users].find(document).one.should eq document
    end

    it "insert multiple documents" do
      documents = [
        { "_id" => Moped::BSON::ObjectId.new, "scope" => scope },
        { "_id" => Moped::BSON::ObjectId.new, "scope" => scope }
      ]

      session[:users].insert(documents)
      session[:users].find(scope: scope).entries.should eq documents
    end

    context "when continuing on error" do

      let(:bson_id) do
        Moped::BSON::ObjectId.new
      end

      let(:documents) do
        documents = [
          { "_id" => bson_id, "scope" => scope },
          { "_id" => bson_id, "scope" => scope },
          { "_id" => Moped::BSON::ObjectId.new, "scope" => scope }
        ]
      end

      before do
        session[:users].insert(documents, [ :continue_on_error ])
      end

      it "inserts all valid documents" do
        session[:users].find(scope: scope).count.should eq(2)
      end
    end
  end

  describe "#collections" do
    before do
      session.drop
      session.command create: "users"
      session.command create: "comments"
    end

    it "returns the name of all non system collections" do
      collections = session.collections
      collections.should be_instance_of(Array)
      collections.each do |collection|
        collection.should be_instance_of(Moped::Collection)
      end
    end
  end
end
