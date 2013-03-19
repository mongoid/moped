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

  describe "#query_options" do

    let(:preference) do
      described_class.new
    end

    it "returns the provided options" do
      expect(preference.query_options({})).to be_empty
    end
  end

  describe "#with_node", replica_set: true do

    let(:preference) do
      described_class.new
    end

    context "when a primary is available" do

      let(:cluster) do
        Moped::Cluster.new([ @primary.address ], {})
      end

      let(:node) do
        preference.with_node(cluster)
      end

      it "yields the primary" do
        preference.with_node(cluster) do |node|
          expect(node).to be_primary
        end
      end
    end

    context "when a primary is not available" do

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
