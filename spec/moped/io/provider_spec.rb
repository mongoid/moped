require "spec_helper"

describe Moped::IO::Provider do

  describe ".pool" do

    let(:node) do
      Moped::Node.new("127.0.0.1:27017")
    end

    context "when accessing from a single thread" do

      let(:pool) do
        described_class.pool(node)
      end

      it "returns the connection pool for the node" do
        expect(pool).to be_a(Moped::IO::ConnectionPool)
      end
    end

    context "when accessing from multiple threads" do

      let(:pool) do
        described_class.pool(node)
      end

      it "always returns the same pool" do
        100.times.map do
          Thread.new do
            expect(described_class.pool(node)).to equal(pool)
          end
        end.each(&:join)
      end
    end
  end
end
