require "spec_helper"

describe Moped::BSON do

  describe ".ObjectId" do

    context "when provided a string" do

      context "when the string is a valid id" do

        let(:id) do
          described_class.ObjectId("4faf83c7dbf89b7b29000001")
        end

        let(:expected) do
          Moped::BSON::ObjectId.from_string("4faf83c7dbf89b7b29000001")
        end

        it "returns an object id" do
          id.should eq(expected)
        end
      end

      context "when the string is not a valid id" do

        it "raises an error" do
          expect {
            described_class.ObjectId("test")
          }.to raise_error(Moped::Errors::InvalidObjectId)
        end
      end
    end

    context "when provided a non string" do

      it "raises an error" do
        expect {
          described_class.ObjectId(1)
        }.to raise_error
      end
    end

    context "when provided nil" do

      it "raises an error" do
        expect {
          described_class.ObjectId(nil)
        }.to raise_error
      end
    end
  end
end
