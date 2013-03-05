require "spec_helper"

describe Moped::Failover::Reconfigure do

  describe "#execute" do

    let(:node) do
      Moped::Node.new("127.0.0.1:27017")
    end

    context "when the exception is reconfiguring a replica set" do

      let(:exception) do
        Moped::Errors::QueryFailure.new({}, { "code" => 13435 })
      end

      it "raises a replica set reconfigured exception" do
        expect {
          described_class.execute(exception, node)
        }.to raise_error(Moped::Errors::ReplicaSetReconfigured)
      end
    end

    context "when no replica set reconfiguration is happening" do

      let(:exception) do
        Moped::Errors::QueryFailure.new({}, {})
      end

      it "raises the exception" do
        expect {
          described_class.execute(exception, node)
        }.to raise_error(exception)
      end
    end
  end
end
