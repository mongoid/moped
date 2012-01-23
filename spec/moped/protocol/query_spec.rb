require "spec_helper"

describe Moped::Protocol::Query do

  let(:query) do
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
        :skip,
        :limit,
        :selector,
        :fields
      ]
    end
  end

  describe "#initialize" do
    let(:query) do
      described_class.new "moped", "people", {a: 1}
    end

    it "sets the database" do
      query.database.should eq "moped"
    end

    it "sets the collection" do
      query.collection.should eq "people"
    end

    it "sets the full collection name" do
      query.full_collection_name.should eq "moped.people"
    end

    it "sets the selector" do
      query.selector.should eq({a:1})
    end

    context "with flag options" do
      let(:query) do
        described_class.new "db", "coll", {}, flags: [:slave_ok, :no_cursor_timeout]
      end

      it "sets the flags" do
        query.flags.should eq [:slave_ok, :no_cursor_timeout]
      end
    end

    context "with a request id option" do
      let(:query) do
        described_class.new "db", "coll", {}, request_id: 10293
      end

      it "sets the request id" do
        query.request_id.should eq 10293
      end
    end

    context "with a limit option" do
      let(:query) do
        described_class.new "db", "coll", {}, limit: 5
      end

      it "sets the limit" do
        query.limit.should eq 5
      end
    end

    context "with a skip option" do
      let(:query) do
        described_class.new "db", "coll", {}, skip: 5
      end

      it "sets the skip" do
        query.skip.should eq 5
      end
    end

    context "with a fields option" do
      let(:query) do
        described_class.new "db", "coll", {}, fields: { a: 1 }
      end

      it "sets the fields" do
        query.fields.should eq({ a: 1})
      end
    end
  end

  describe "#op_code" do
    it "should eq 2004" do
      query.op_code.should eq 2004
    end
  end

end
