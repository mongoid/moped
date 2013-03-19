require "spec_helper"

describe Moped::WriteConcern::Unverified do

  describe "#operation" do

    let(:concern) do
      described_class.new
    end

    it "returns nil" do
      expect(concern.operation).to be_nil
    end
  end
end
