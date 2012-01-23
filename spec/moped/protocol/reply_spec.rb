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
      data << Moped::BSON::Document.serialize({"a" => "b"})
      data << Moped::BSON::Document.serialize({"a" => "b"})

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

end
