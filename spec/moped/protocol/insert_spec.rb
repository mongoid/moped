require "spec_helper"

describe Moped::Protocol::Insert do

  let(:insert) do
    described_class.allocate
  end

  describe ".fields" do
    it "matches the specification's field list" do
      described_class.fields.should eq [
        :length,
        :request_id,
        :response_to,
        :op_code,
        :flags,
        :full_collection_name,
        :documents
      ]
    end
  end

  describe "#initialize" do
    let(:insert) do
      described_class.new("moped", "people", [{a: 1}])
    end

    it "sets the database" do
      insert.database.should eq "moped"
    end

    it "sets the collection" do
      insert.collection.should eq "people"
    end

    it "sets the full collection name" do
      insert.full_collection_name.should eq "moped.people"
    end

    it "sets the documents array" do
      insert.documents.should eq [{a: 1}]
    end

    context "with flag options" do
      let(:insert) do
        described_class.new "db", "coll", [], flags: [:continue_on_error]
      end

      it "sets the flags" do
        insert.flags.should eq [:continue_on_error]
      end
    end

    context "with a request id option" do
      let(:insert) do
        described_class.new "db", "coll", [], request_id: 10293
      end

      it "sets the request id" do
        insert.request_id.should eq 10293
      end
    end
  end

  describe "#op_code" do
    it "should eq 2002" do
      insert.op_code.should eq 2002
    end
  end

end
