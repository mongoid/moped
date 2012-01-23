require "spec_helper"

describe Moped::Protocol::Update do

  let(:update) do
    described_class.allocate
  end

  describe ".fields" do
    it "matches the specification's field list" do
      described_class.fields.should eq [
        :length,
        :request_id,
        :response_to,
        :op_code,
        :reserved,
        :full_collection_name,
        :flags,
        :selector,
        :update
      ]
    end
  end

  describe "#initialize" do
    let(:update) do
      described_class.new "moped", "people", { a: 1 }, { a: 2 }
    end

    it "sets the database" do
      update.database.should eq "moped"
    end

    it "sets the collection" do
      update.collection.should eq "people"
    end

    it "sets the full collection name" do
      update.full_collection_name.should eq "moped.people"
    end

    it "sets the selector" do
      update.selector.should eq({ a: 1 })
    end

    it "sets the update" do
      update.update.should eq({ a: 2 })
    end

    context "with flag options" do
      let(:update) do
        described_class.new "db", "coll", {}, {}, flags: [:upsert]
      end

      it "sets the flags" do
        update.flags.should eq [:upsert]
      end
    end

    context "with a request id option" do
      let(:update) do
        described_class.new "db", "coll", {}, {}, request_id: 10293
      end

      it "sets the request id" do
        update.request_id.should eq 10293
      end
    end
  end

  describe "#op_code" do
    it "should eq 2001" do
      update.op_code.should eq 2001
    end
  end

end
