require "spec_helper"

describe Moped::Connection::Manager do

  describe ".pool" do

    let(:node) do
      Moped::Node.new("127.0.0.1:27017", timeout: 5)
    end

    context "when accessing from a single thread" do

      let(:pool) do
        described_class.pool(node)
      end

      it "returns the connection pool for the node" do
        expect(pool).to be_a(Moped::Connection::Pool)
      end
    end

    context "when accessing from multiple threads" do

      let(:pool) do
        described_class.pool(node)
      end

      let(:threads) do
        []
      end

      it "always returns the same pool" do
        10.times.map do
          threads << Thread.new do
            expect(described_class.pool(node)).to equal(pool)
          end
        end
        threads.each(&:value)
      end
    end
  end
end
