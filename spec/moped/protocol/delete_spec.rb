require "spec_helper"

describe Moped::Protocol::Delete do

  let(:delete) do
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
        :selector
      ]
    end
  end

  describe "#initialize" do
    let(:delete) do
      described_class.new "moped", "people", { cond: true }
    end

    it "sets the database" do
      delete.database.should eq "moped"
    end

    it "sets the collection" do
      delete.collection.should eq "people"
    end

    it "sets the full collection name" do
      delete.full_collection_name.should eq "moped.people"
    end

    it "sets the selector" do
      delete.selector.should eq({ cond: true })
    end

    context "with flags option" do
      let(:delete) do
        described_class.new "moped", "people", { cond: true },
          flags: [:remove_first]
      end

      it "sets the flags" do
        delete.flags.should eq [:remove_first]
      end
    end

    context "with request id option" do
      let(:delete) do
        described_class.new "moped", "people", { cond: true },
          request_id: 123
      end

      it "sets the request id" do
        delete.request_id.should eq 123
      end
    end
  end

  describe "#op_code" do
    it "should eq 2006" do
      delete.op_code.should eq 2006
    end
  end

end
