require "spec_helper"

describe Moped::Failover do

  describe ".get" do

    context "when providing an unregistered exception" do

      let(:failover) do
        described_class.get(RuntimeError.new)
      end

      it "returns disconnect" do
        expect(failover).to be_a(Moped::Failover::Disconnect)
      end
    end

    context "when providing a registered exception" do

      context "when providing an operation failure" do

        let(:failover) do
          described_class.get(Moped::Errors::OperationFailure.new({}, {}))
        end

        it "returns a reconfigure" do
          expect(failover).to be_a(Moped::Failover::Reconfigure)
        end
      end

      context "when providing a query failure" do

        let(:failover) do
          described_class.get(Moped::Errors::QueryFailure.new({}, {}))
        end

        it "returns a reconfigure" do
          expect(failover).to be_a(Moped::Failover::Reconfigure)
        end
      end

      context "when providing a cursor not found" do

        let(:failover) do
          described_class.get(Moped::Errors::CursorNotFound.new({}, 123))
        end

        it "returns an ignore" do
          expect(failover).to be_a(Moped::Failover::Ignore)
        end
      end

      context "when providing an authentication failure" do

        let(:failover) do
          described_class.get(Moped::Errors::AuthenticationFailure.new({}, {}))
        end

        it "returns an ignore" do
          expect(failover).to be_a(Moped::Failover::Ignore)
        end
      end

      context "when providing a connection failure" do

        let(:failover) do
          described_class.get(Moped::Errors::ConnectionFailure.new({}))
        end

        it "returns a retry" do
          expect(failover).to be_a(Moped::Failover::Retry)
        end
      end
    end
  end
end
