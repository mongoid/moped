require "spec_helper"

describe Moped::Failover::Ignore do

  describe "#initialize" do

    let(:exception) do
      RuntimeError.new
    end

    let(:ignore) do
      described_class.new(exception)
    end

    it "sets the exception" do
      expect(ignore.exception).to eq(exception)
    end
  end

  describe "#execute" do

    let(:exception) do
      RuntimeError.new
    end

    let(:node) do
      Moped::Node.new("127.0.0.1:27017")
    end

    let(:ignore) do
      described_class.new(exception)
    end

    it "raises the exception" do
      expect {
        ignore.execute(node)
      }.to raise_error(exception)
    end
  end
end
