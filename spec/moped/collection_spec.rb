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

  describe "#initialize" do

    let(:database) do
      session.send(:current_database)
    end

    let(:collection) do
      described_class.new(database, :users)
    end

    it "converts the collection name to a string" do
      collection.name.should eq("users")
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

  describe "#aggregate" do

    let(:documents) do
      [
        { _id: "10001", city: "NEW YORK", pop: 18913, state: "NY"},
        { _id: "10002", city: "NEW YORK", pop: 84143, state: "NY"},
        { _id: "89101", city: "LAS VEGAS", pop: 40270, state: "NV"},
        { _id: "89102", city: "LAS VEGAS", pop: 48070, state: "NV"}
      ]
    end

    before do
      session[:zips].insert(documents)
    end

    context "with one group operation" do

      let(:result) do
        session[:zips].aggregate({
          "$group" => {
            "_id" => "$city",
            "totalpop" => { "$sum" => "$pop" }
          }
        })
      end

      it "returns a grouped result" do
        result.size.should eq(2)
      end

      it "returns a grouped result with sum" do
        result.first["totalpop"].should_not be_nil
      end
    end

    context "with more than one operation" do

      let(:result) do
        session[:zips].aggregate([
          { "$group" =>
            {
              "_id" => "$city",
              "totalpop" => { "$sum" => "$pop" }
            }
          },
          { "$match" => { "totalpop" => { "$gte" => 100000 }}}
        ])
      end

      it "returns an aggregated result" do
        result.size.should eq(1)
      end

      it "returns an aggregated result with grouped and matched documents" do
        result.first["totalpop"].should eq(18913 + 84143)
      end
    end
  end
end
