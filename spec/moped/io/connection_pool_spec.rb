require "spec_helper"

describe Moped::IO::ConnectionPool do

  describe "#initialize" do

    context "when provided no options" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017)
      end

      it "defaults the max size to 5" do
        expect(pool.max_size).to eq(5)
      end
    end

    context "when provided options" do

      context "when provided a max size" do

        let(:pool) do
          described_class.new("127.0.0.1", 27017, max_size: 2)
        end

        it "set the max size to the provided value" do
          expect(pool.max_size).to eq(2)
        end

        it "sets the options" do
          expect(pool.options).to eq(max_size: 2)
        end
      end
    end
  end

  describe "#saturated?" do

    let(:pool) do
      described_class.new("127.0.0.1", 27017, max_size: 2)
    end

    context "when the pool is not saturated" do

      it "returns false" do
        expect(pool).to_not be_saturated
      end
    end

    context "when the pool is saturated" do

      let(:conn_one) do
        Moped::IO::Connection.new("127.0.0.1", 27017, 5)
      end

      let(:conn_two) do
        Moped::IO::Connection.new("127.0.0.1", 27017, 5)
      end

      before do
        pool.checkin(conn_one)
        pool.checkin(conn_two)
      end

      it "returns true" do
        expect(pool).to be_saturated
      end
    end
  end

  describe "#with_connection" do

    let(:pool) do
      described_class.new("127.0.0.1", 27017)
    end

    context "when accessing from a single thread" do

      context "when the pool is empty" do

        it "yields a new connection" do
          pool.with_connection do |connection|
            expect(connection).to be_a(Moped::IO::Connection)
          end
        end
      end
    end
  end
end
