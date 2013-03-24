require "spec_helper"

describe Moped::Connection::Pool do

  describe "#checkout" do

    context "when no connections exist in the pool" do

      it "creates a new connection" do

      end

      it "pins the connection to the thread" do

      end

      it "updates the checked out count" do

      end
    end
  end

  describe "#max_size" do

    context "when the max_size option is provided" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017, max_size: 2)
      end

      it "returns the max size" do
        expect(pool.max_size).to eq(2)
      end
    end

    context "when no option is provided" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017)
      end

      it "returns the default" do
        expect(pool.max_size).to eq(5)
      end
    end
  end

  describe "#timeout" do

    context "when the timeout option is provided" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017, pool_timeout: 2)
      end

      it "returns the timeout" do
        expect(pool.timeout).to eq(2)
      end
    end

    context "when no option is provided" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017)
      end

      it "returns the default" do
        expect(pool.timeout).to eq(0.25)
      end
    end
  end
end
