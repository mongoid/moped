require "spec_helper"

describe Moped::Errors::MongoError do

  describe "#message" do

    context "when an assertionCode is in the details" do

      let(:command) do
        Moped::Protocol::Command.new(:moped_test, "")
      end

      let(:result) do
        { "assertionCode" => 9014, "assertion" => "The map/reduce failed" }
      end

      let(:error) do
        described_class.new(command, result)
      end

      let(:message) do
        error.message
      end

      it "returns the assertion code in the error" do
        message.should include("9014")
      end

      it "returns the assertion message in the error" do
        message.should include("The map/reduce failed")
      end
    end
  end
end
