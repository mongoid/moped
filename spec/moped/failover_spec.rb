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

    context "when providing a registered exception" do

      context "when providing an operation failure" do

        let(:failover) do
          described_class.get(Moped::Errors::OperationFailure)
        end

        it "returns a reconfigure" do
          expect(failover).to be_a(Moped::Failover::Reconfigure)
        end
      end

      context "when providing a query failure" do

        let(:failover) do
          described_class.get(Moped::Errors::QueryFailure)
        end

        it "returns a reconfigure" do
          expect(failover).to be_a(Moped::Failover::Reconfigure)
        end
      end
    end
  end
end
