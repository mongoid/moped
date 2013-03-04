require "spec_helper"

describe Moped::Protocol::Command do

  describe "#failure?" do

    let(:command) do
      described_class.new(:moped, ismaster: 1)
    end

    let(:reply) do
      Moped::Protocol::Reply.new
    end

    context "when the reply is a command failure" do

      before do
        reply.documents = [{ "ok" => 0.0 }]
      end

      it "returns true" do
        expect(command).to be_failure(reply)
      end
    end

    context "when the reply is not a command failure" do

      before do
        reply.documents = [{ "ok" => 1.0 }]
      end

      it "returns true" do
        expect(command).to_not be_failure(reply)
      end
    end
  end

  describe "#failure_exception" do

    let(:command) do
      described_class.new(:moped, ismaster: 1)
    end

    let(:reply) do
      Moped::Protocol::Reply.new.tap do |message|
        message.documents = [{}]
      end
    end

    let(:exception) do
      command.failure_exception(reply)
    end

    it "returns a query failure" do
      expect(exception).to be_a(Moped::Errors::OperationFailure)
    end
  end

  describe "#initialize" do

    let(:command) do
      described_class.new(:moped, ismaster: 1)
    end

    it "sets the query's full collection name" do
      expect(command.full_collection_name).to eq("moped.$cmd")
    end

    it "sets the query's selector to the command provided" do
      expect(command.selector).to eq(ismaster: 1)
    end

    it "sets the query's limit to -1" do
      expect(command.limit).to eq(-1)
    end
  end
end
