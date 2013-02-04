require "spec_helper"

describe Moped::BSON::Binary do

  context "when serializing and deserializing" do

    let(:io) do
      StringIO.new(raw)
    end

    context "when the type is :generic" do

      it_behaves_like "a serializable bson object" do
        let(:raw) { "\x16\x00\x00\x00\x05data\x00\x06\x00\x00\x00\x00binary\x00" }
        let(:doc) { {"data" => Moped::BSON::Binary.new(:generic, "binary") } }
      end
    end

    context "when the type is :function" do

      it_behaves_like "a serializable bson object" do
        let(:raw) { "\x16\x00\x00\x00\x05data\x00\x06\x00\x00\x00\x01binary\x00" }
        let(:doc) { {"data" => Moped::BSON::Binary.new(:function, "binary") } }
      end
    end

    context "when the type is :old" do

      it_behaves_like "a serializable bson object" do
        let(:raw) { "\x1A\x00\x00\x00\x05data\x00\n\x00\x00\x00\x02\x06\x00\x00\x00binary\x00" }
        let(:doc) { {"data" => Moped::BSON::Binary.new(:old, "binary") } }
      end
    end

    context "when the type is :uuid" do
      it_behaves_like "a serializable bson object" do
        let(:raw) { "\x16\x00\x00\x00\x05data\x00\x06\x00\x00\x00\x03binary\x00" }
        let(:doc) { {"data" => Moped::BSON::Binary.new(:uuid, "binary") } }
      end
    end

    context "when the type is :md5" do

      it_behaves_like "a serializable bson object" do

        let(:raw) { "\x16\x00\x00\x00\x05data\x00\x06\x00\x00\x00\x05binary\x00" }
        let(:doc) { {"data" => Moped::BSON::Binary.new(:md5, "binary") } }
      end
    end

    context "when the type is :user" do

      it_behaves_like "a serializable bson object" do

        let(:raw) { "\x16\x00\x00\x00\x05data\x00\x06\x00\x00\x00\x80binary\x00" }
        let(:doc) { {"data" => Moped::BSON::Binary.new(:user, "binary") } }
      end
    end
  end
end
