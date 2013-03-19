require "spec_helper"

describe Moped::ReadPreference::Nearest do

  describe "#name" do

    let(:preference) do
      described_class.new
    end

    it "returns nearest" do
      expect(preference.name).to eq(:nearest)
    end
  end

  describe "#with_node", replica_set: true do

    let(:preference) do
      described_class.new
    end

    context "when primary or secondaries are available" do

      let(:cluster) do
        Moped::Cluster.new([ @primary.address ], {})
      end

      let(:nearest) do
        cluster.nodes.sort_by(&:latency).first
      end

      it "returns the nearest node" do
        preference.with_node(cluster) do |node|
          expect(node).to eq(nearest)
        end
      end
    end

    context "when no nodes are available" do

      let(:cluster) do
        Moped::Cluster.new([], {})
      end

      it "raises an error" do
        expect {
          preference.with_node(cluster) {}
        }.to raise_error(Moped::Errors::ConnectionFailure)
      end
    end
  end
end
