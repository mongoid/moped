require "spec_helper"

describe Moped::ReadPreference::PrimaryPreferred do

  describe "#name" do

    let(:preference) do
      described_class.new
    end

    it "returns primaryPreferred" do
      expect(preference.name).to eq(:primaryPreferred)
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

      it "returns the primary" do
        preference.with_node(cluster) do |node|
          expect(node).to be_primary
        end
      end
    end

    context "when a primary is not available" do

      context "when a secondary is available" do

        let(:cluster) do
          Moped::Cluster.new([ @secondaries.first.address ], {})
        end

        before do
          @primary.stop
        end

        it "returns the secondary" do
          preference.with_node(cluster) do |node|
            expect(node).to be_secondary
          end
        end
      end

      context "when a secondary is not available" do

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
end
