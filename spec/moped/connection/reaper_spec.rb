require "spec_helper"

describe Moped::Connection::Reaper do

  describe "#initialize" do

    let(:pool) do
      Moped::Connection::Pool.new("127.0.0.1", 27017, pool_size: 2)
    end

    let(:reaper) do
      described_class.new(2, pool)
    end

    it "sets the connection pool" do
      expect(reaper.pool).to eq(pool)
    end

    it "sets the interval" do
      expect(reaper.interval).to eq(2)
    end
  end

  describe "#start" do

    let(:pool) do
      Moped::Connection::Pool.new("127.0.0.1", 27017, pool_size: 2)
    end

    let(:reaper) do
      described_class.new(2, pool)
    end

    context "when connections exist for dead threads" do

      let(:thread) do
        reaper.start
      end

      let(:unpinned) do
        pool.send(:unpinned)
      end

      before do
        Thread.new do
          pool.checkout
        end.join
        thread
        sleep(3)
      end

      after do
        thread.kill
      end

      it "reaps the connections" do
        expect(unpinned.size).to eq(2)
      end
    end
  end
end
