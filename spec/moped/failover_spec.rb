require "spec_helper"

describe Moped::Failover do

  describe ".get" do

    context "when providing an unregistered exception" do

      let(:failover) do
        described_class.get(RuntimeError)
      end

      it "returns ignore" do
        expect(failover).to be_a(Moped::Failover::Ignore)
      end
    end
  end
end
