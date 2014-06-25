require "spec_helper"

describe Moped::Address do

  describe "#initialize" do

    context "when a port is provided" do

      let(:address) do
        described_class.new("127.0.0.1:27017", 2)
      end

      it "sets the original address" do
        expect(address.original).to eq("127.0.0.1:27017")
      end

      it "sets the host" do
        expect(address.host).to eq("127.0.0.1")
      end

      it "sets the port" do
        expect(address.port).to eq(27017)
      end
    end

    context "when no port is provided" do

      let(:address) do
        described_class.new("localhost", 2)
      end

      it "sets the original address" do
        expect(address.original).to eq("localhost")
      end

      it "sets the host" do
        expect(address.host).to eq("localhost")
      end

      it "defaults the port to 27017" do
        expect(address.port).to eq(27017)
      end
    end
  end

  describe "#resolve" do

    context "when the host is an ip" do

      let(:node) do
        Moped::Node.new("127.0.0.1:27017")
      end

      let(:address) do
        described_class.new("127.0.0.1:27017", 2)
      end

      before do
        address.resolve(node)
      end

      it "sets the resolved address" do
        expect(address.resolved).to eq("127.0.0.1:27017")
      end

      it "sets the ip" do
        expect(address.ip).to eq("127.0.0.1")
      end
    end

    context "when the host is a name" do

      let(:node) do
        Moped::Node.new("localhost:27017")
      end

      let(:address) do
        described_class.new("localhost:27017", 2)
      end

      before do
        address.resolve(node)
      end

      it "sets the resolved address" do
        expect(address.resolved).to eq("127.0.0.1:27017")
      end

      it "sets the ip" do
        expect(address.ip).to eq("127.0.0.1")
      end
    end

    context "when the host is a name and is not resolved" do

      let(:node) do
        Moped::Node.new("localhost:27017", resolve: false)
      end

      let(:address) do
        Moped::Address.new("localhost:27017", 2)
      end

      before do
        address.resolve(Moped::Node.new("localhost:27017", resolve: false))
      end

      it "sets the resolved address" do
        expect(address.resolved).to eq("localhost:27017")
      end

      it "sets the ip" do
        expect(address.ip).to eq(nil)
      end
    end

    context "when the host cannot be resolved" do

      let(:node) do
        Moped::Node.new("notahost:27017")
      end

      let(:address) do
        described_class.new("notahost:27017", 1)
      end

      let!(:resolved) do
        address.resolve(node)
      end

      it "does not set the resolved address" do
        expect(address.resolved).to be_nil
      end

      it "does not set the ip" do
        expect(address.ip).to be_nil
      end

      it "flags the node as down" do
        expect(node).to be_down
      end

      it "returns false" do
        expect(resolved).to be_false
      end
    end
  end
end
