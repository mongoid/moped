require "spec_helper"

describe Moped::Collection do
  let(:session) do
    Moped::Session.new %w[127.0.0.1:27017], database: "moped_test"
  end

  let(:scope) { object_id }

  describe "#drop" do
    before do
      session.drop
      session.command create: "users"
    end

    it "drops the collection" do
      result = session[:users].drop
      result["ns"].should eq "moped_test.users"
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
  end
end
