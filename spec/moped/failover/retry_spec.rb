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

      before do
        node.send(:connect)
      end

      it "re-raises the exception" do
        expect {
          described_class.execute(exception, node) do
            raise(exception)
          end
        }.to raise_error(exception.class)
      end

      it "disconnects the node" do
        begin
          described_class.execute(exception, node) do
            raise(exception)
          end
        rescue Exception => e
          expect(node).to_not be_connected
        end
      end

      it "flags the node as down" do
        begin
          described_class.execute(exception, node) do
            raise(exception)
          end
        rescue Exception => e
          expect(node).to be_down
        end
      end
    end
  end
end
