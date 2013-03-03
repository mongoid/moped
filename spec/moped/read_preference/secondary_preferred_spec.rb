require "spec_helper"

describe Moped::ReadPreference::SecondaryPreferred do

  describe "#select", replica_set: true do

    let(:nodes) do
      @replica_set.nodes
    end

    let(:primary) do
      Moped::Node.new(@primary.address)
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
        described_class.select(ring)
      end

      it "returns the secondary" do
        expect(node).to eq(secondary)
      end
    end

    context "when a secondary is not available" do

      context "when a primary is available" do

        let(:ring) do
          Moped::Ring.new([ primary ])
        end

        before do
          primary.refresh
        end

        let(:node) do
          described_class.select(ring)
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
            described_class.select(ring)
          }.to raise_error(Moped::ReadPreference::Unavailable)
        end
      end
    end
  end
end
