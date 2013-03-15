require "spec_helper"

describe Moped::Failover::Ignore do

  describe "#execute" do

    let(:exception) do
      RuntimeError.new
    end

    let(:node) do
      Moped::Node.new("127.0.0.1:27017")
    end

    it "raises the exception" do
      expect {
        described_class.execute(exception, node)
      }.to raise_error(exception.class)
    end
  end
end
