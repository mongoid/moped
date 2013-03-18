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

    context "when a secondary is available" do

      let(:cluster) do
        Moped::Cluster.new(@secondaries.map(&:address), {})
      end

      it "returns the secondary" do
        preference.with_node(cluster) do |node|
          expect(node).to be_secondary
        end
      end
    end

    context "when a secondary is not available" do

      let(:cluster) do
        Moped::Cluster.new([ @primary.address ], {})
      end

      before do
        @secondaries.each(&:stop)
      end

      it "raises an error" do
        expect {
          preference.with_node(cluster) {}
        }.to raise_error(Moped::Errors::ConnectionFailure)
      end
    end
  end
end
