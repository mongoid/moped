require "spec_helper"

describe Moped::IO::Connection do

  describe "#alive?" do

    let(:connection) do
      described_class.new("127.0.0.1", 27017, 2)
    end

    after do
      connection.disconnect
    end

    context "when the socket is alive" do

      before do
        connection.connect
      end

      it "returns true" do
        expect(connection).to be_alive
      end
    end

    context "when the socket is not alive" do

      before do
        connection.connect
        connection.instance_variable_get(:@sock).close
      end

      it "returns false" do
        expect(connection).to_not be_alive
      end
    end

    context "when the socket is nil" do

      it "returns false" do
        expect(connection).to_not be_alive
      end
    end
  end
end
