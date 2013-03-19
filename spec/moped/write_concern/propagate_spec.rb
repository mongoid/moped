require "spec_helper"

describe Moped::WriteConcern::Propagate do

  describe "#operation" do

    let(:concern) do
      described_class.new(w: 1)
    end

    it "returns the gle command" do
      expect(concern.operation).to eq(getlasterror: 1, w: 1)
    end
  end

  describe "#initialize" do

    context "when the concern is an options hash" do

      let(:concern) do
        described_class.new(w: 3)
      end

      it "merges the options into the gle" do
        expect(concern.operation).to eq(getlasterror: 1, w: 3)
      end
    end
  end
end
