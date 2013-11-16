require "spec_helper"

describe Moped::Failover::Disconnect do

  describe "#execute" do

    let(:exception) do
      IOError.new
    end

    let(:node) do
      Moped::Node.new("127.0.0.1:27017")
    end

    it "raises a socket error" do
      expect {
        described_class.execute(exception, node)
      }.to raise_error(Moped::Errors::SocketError)
    end

    it "disconnects the node" do
      begin
        described_class.execute(exception, node)
      rescue Moped::Errors::SocketError
        expect(node).to_not be_connected
      end
    end
  end
end
