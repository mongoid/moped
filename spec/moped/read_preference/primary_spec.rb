require "spec_helper"

describe Moped::ReadPreference::Primary do

  describe "#name" do

    let(:preference) do
      described_class.new
    end

    it "returns primary" do
      expect(preference.name).to eq(:primary)
    end
  end

  describe "#select", replica_set: true do

    let(:preference) do
      described_class.new
    end

    let(:nodes) do
      @replica_set.nodes
    end

    let(:primary) do
      Moped::Node.new(@primary.address)
    end

    context "when a primary is available" do

      let(:ring) do
        Moped::Ring.new([ primary ])
      end

      before do
        primary.refresh
      end

      let(:node) do
        preference.select(ring)
      end

      it "returns the primary" do
        expect(node).to eq(primary)
      end
    end

    context "when a primary is not available" do

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
