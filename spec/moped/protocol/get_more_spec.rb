require "spec_helper"

describe Moped::Protocol::GetMore do

  let(:get_more) do
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
        :limit,
        :cursor_id
      ]
    end
  end

  describe "#initialize" do
    let(:get_more) do
      described_class.new "moped", "people", 123, 10
    end

    it "sets the database" do
      get_more.database.should eq "moped"
    end

    it "sets the collection" do
      get_more.collection.should eq "people"
    end

    it "sets the full collection name" do
      get_more.full_collection_name.should eq "moped.people"
    end

    it "sets the cursor id" do
      get_more.cursor_id.should eq 123
    end

    it "sets the limit" do
      get_more.limit.should eq 10
    end

    context "when request id option is supplied" do
      let(:get_more) do
        described_class.new "moped", "people", 123, 10, request_id: 123
      end
      it "sets the request id" do
        get_more.request_id.should eq 123
      end
    end
  end

  describe "#op_code" do
    it "should eq 2005" do
      get_more.op_code.should eq 2005
    end
  end

end
