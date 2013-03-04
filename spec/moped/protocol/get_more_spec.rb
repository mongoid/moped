require "spec_helper"

describe Moped::Protocol::GetMore do

  describe "#failure?" do

    let(:get_more) do
      described_class.new("moped", "people", 123, 10)
    end

    let(:reply) do
      Moped::Protocol::Reply.new
    end

    context "when the reply is a query failure" do

      before do
        reply.flags = [ :query_failure ]
      end

      it "returns true" do
        expect(get_more).to be_failure(reply)
      end
    end

    context "when the reply is a cursor not found" do

      before do
        reply.flags = [ :cursor_not_found ]
      end

      it "returns true" do
        expect(get_more).to be_failure(reply)
      end
    end

    context "when the reply is not a failure" do

      before do
        reply.documents = [{}]
      end

      it "returns true" do
        expect(get_more).to_not be_failure(reply)
      end
    end
  end

  describe "#failure_exception" do

    let(:get_more) do
      described_class.new("moped", "people", 123, 10)
    end

    context "when the reply failure is query" do

      let(:reply) do
        Moped::Protocol::Reply.new.tap do |message|
          message.documents = [{}]
          message.flags = [ :query_failure ]
        end
      end

      let(:exception) do
        get_more.failure_exception(reply)
      end

      it "returns a cursor not found" do
        expect(exception).to be_a(Moped::Errors::QueryFailure)
      end
    end

    context "when the reply failure is cursor not found" do

      let(:reply) do
        Moped::Protocol::Reply.new.tap do |message|
          message.documents = [{}]
          message.flags = [ :cursor_not_found ]
        end
      end

      let(:exception) do
        get_more.failure_exception(reply)
      end

      it "returns a cursor not found" do
        expect(exception).to be_a(Moped::Errors::CursorNotFound)
      end
    end
  end

  describe ".fields" do

    it "matches the specification's field list" do
      expect(described_class.fields).to eq([
        :length, :request_id, :response_to, :op_code, :reserved,
        :full_collection_name, :limit, :cursor_id
      ])
    end
  end

  describe "#initialize" do

    let(:get_more) do
      described_class.new("moped", "people", 123, 10)
    end

    it "sets the database" do
      expect(get_more.database).to eq("moped")
    end

    it "sets the collection" do
      expect(get_more.collection).to eq("people")
    end

    it "sets the full collection name" do
      expect(get_more.full_collection_name).to eq("moped.people")
    end

    it "sets the cursor id" do
      expect(get_more.cursor_id).to eq(123)
    end

    it "sets the limit" do
      expect(get_more.limit).to eq(10)
    end

    context "when a request id option is supplied" do

      let(:get_more) do
        described_class.new("moped", "people", 123, 10, request_id: 123)
      end

      it "sets the request id" do
        expect(get_more.request_id).to eq(123)
      end
    end
  end

  describe "#op_code" do

    let(:get_more) do
      described_class.allocate
    end

    it "should eq 2005" do
      expect(get_more.op_code).to eq(2005)
    end
  end

  describe "#results" do

    let(:get_more) do
      described_class.new("moped", "people", 123, 10, request_id: 123)
    end

    let(:reply) do
      Moped::Protocol::Reply.new
    end

    it "returns the reply" do
      expect(get_more.results(reply)).to eq(reply)
    end
  end
end
