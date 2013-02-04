require "spec_helper"

describe Moped::BSON::MinKey do

  context "when serializing and deserializing" do

    let(:io) do
      StringIO.new(raw)
    end

    it_behaves_like "a serializable bson object" do

      let(:raw) { "\b\x00\x00\x00\xFFn\x00\x00" }
      let(:doc) { {"n" => Moped::BSON::MinKey} }
    end
  end
end
