require "spec_helper"

describe Moped::Failover::Retry do

  describe "#execute" do

    let(:node) do
      Moped::Node.new("127.0.0.1:27017")
    end

    let(:exception) do
      Moped::Errors::ConnectionFailure.new
    end

    context "when the retry succeeds" do

      it "returns the result of the yield" do
        expect(described_class.execute(exception, node) { "test" }).to eq("test")
      end
    end

    context "when the retry fails" do

      it "re-raises the exception" do
        expect {
          described_class.execute(exception, node) do
            raise(exception)
          end
        }.to raise_error(exception)
      end
    end
  end
end
