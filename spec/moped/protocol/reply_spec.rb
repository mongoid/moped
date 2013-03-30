require "spec_helper"

describe Moped::Protocol::Reply do

  let(:reply) do
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
        :cursor_id,
        :offset,
        :count,
        :documents
      ]
    end
  end

  describe ".deserialize" do
    let(:raw) do
      # assemble sample headers
      data = [1, 1, 1, 3, 291029, 10, 2].pack('V4QV2')

      # add a returned document
      data << {"a" => "b"}.to_bson
      data << {"a" => "b"}.to_bson

      # finally write the length
      data = [data.length + 4].pack('V') + data
    end

    let(:buffer) { StringIO.new raw }
    let(:reply) { Moped::Protocol::Reply.deserialize(buffer) }

    it "sets the length" do
      reply.length.should eq raw.length
    end

    it "sets the request id" do
      reply.request_id.should eq 1
    end

    it "sets the response to field" do
      reply.response_to.should eq 1
    end

    it "sets the op_code" do
      reply.op_code.should eq 1
    end

    it "sets the flags" do
      reply.flags.should eq [:cursor_not_found, :query_failure]
    end

    it "sets the cursor id " do
      reply.cursor_id.should eq 291029
    end

    it "sets the offset" do
      reply.offset.should eq 10
    end

    it "sets the number of documents" do
      reply.count.should eq 2
    end

    it "sets the documents" do
      reply.documents.should == [{"a" => "b"}, {"a" => "b"}]
    end
  end

  describe "#command_failed?" do

    context "when ok is not 1" do

      let(:error) do
        { "ok" => 0 }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_command_failure
      end
    end

    context "when an err message is present" do

      let(:error) do
        { "err" => "message" }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_command_failure
      end
    end

    context "when an errmsg message is present" do

      let(:error) do
        { "errmsg" => "message" }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_command_failure
      end
    end

    context "when an $err is present" do

      let(:error) do
        { "$err" => "message" }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_command_failure
      end
    end

    context "when no errors exist" do

      let(:error) do
        { "ok" => 1 }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns false" do
        reply.should_not be_command_failure
      end
    end
  end

  describe "#error?" do

    let(:reply) do
      described_class.new
    end

    before do
      reply.documents = []
    end

    context "when no documents exist" do

      it "returns false" do
        expect(reply).to_not be_error
      end
    end

    context "when documents exist" do

      context "when the first document has an 'err' key" do

        before do
          reply.documents = [{ "err" => 1 }]
        end

        it "returns true" do
          expect(reply).to be_error
        end
      end

      context "when the first document has an 'errmsg' key" do

        before do
          reply.documents = [{ "errmsg" => 1 }]
        end

        it "returns true" do
          expect(reply).to be_error
        end
      end

      context "when the first document has an '$err' key" do

        before do
          reply.documents = [{ "$err" => 1 }]
        end

        it "returns true" do
          expect(reply).to be_error
        end
      end

      context "when no error keys exist" do

        before do
          reply.documents = [{}]
        end

        it "returns false" do
          expect(reply).to_not be_error
        end
      end
    end
  end

  describe "#query_failure?" do

    context "when an $err is present" do

      let(:error) do
        { "$err" => "message" }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_query_failure
      end
    end

    context "when the query_failure flag is present" do

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = []
        reply.flags = [ :query_failure ]
      end

      it "returns true" do
        reply.should be_query_failure
      end
    end
  end

  describe "#unauthorized?" do

    context "when the code is unauthorized" do

      let(:error) do
        { "ok" => 0, "err" => "message", "code" => 10057 }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_unauthorized
      end
    end

    context "when the assertion code is unauthorized" do

      let(:error) do
        { "ok" => 0, "err" => "message", "assertionCode" => 16550 }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_unauthorized
      end
    end

    context "when the error message says unauthorized" do
      let(:error) do
        { "ok" => 0, "err" => "unauthorized", "assertionCode" => 2004 }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns true" do
        reply.should be_unauthorized
      end
    end

    context "when no auth errors exist" do

      let(:error) do
        { "ok" => 1 }
      end

      let(:reply) do
        described_class.new
      end

      before do
        reply.documents = [ error ]
      end

      it "returns false" do
        reply.should_not be_unauthorized
      end
    end
  end
end
