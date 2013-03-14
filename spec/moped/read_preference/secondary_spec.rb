require "spec_helper"

describe Moped::ReadPreference::Secondary do

  describe "#name" do

    let(:preference) do
      described_class.new
    end

    it "returns secondary" do
      expect(preference.name).to eq(:secondary)
    end
  end

  describe "#select", replica_set: true do

    let(:preference) do
      described_class.new
    end

    let(:nodes) do
      @replica_set.nodes
    end

    let(:secondary) do
      Moped::Node.new(@secondaries.first.address)
    end

    context "when a secondary is available" do

      let(:ring) do
        Moped::Ring.new([ secondary ])
      end

      before do
        secondary.refresh
      end

      let(:node) do
        preference.select(ring)
      end

      it "returns the secondary" do
        expect(node).to eq(secondary)
      end
    end

    context "when a secondary is not available" do

      let(:ring) do
        Moped::Ring.new([])
      end

      it "raises an error" do
        expect {
          preference.select(ring)
        }.to raise_error(Moped::ReadPreference::Unavailable)
      end
    end
  end
end
