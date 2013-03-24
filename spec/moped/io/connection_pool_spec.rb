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
        pool.send(:checkin, conn_one)
        pool.send(:checkin, conn_two)
      end

      it "returns true" do
        expect(pool).to be_saturated
      end
    end
  end

  describe "#connection" do

    let(:pool) do
      described_class.new("127.0.0.1", 27017)
    end

    context "when accessing from multiple threads" do

      context "when there are more active threads than the max pool size" do

        it "raises an error" do
          expect {
            6.times do
              Thread.new do
                pool.connection do |conn|
                  expect(conn).to be_a(Moped::IO::Connection)
                end
              end.join
            end
          }.to raise_error
        end
      end

      context "when unpinning connections on thread finish" do

        it "allows infinite thread creation" do
          10.times do
            Thread.new do
              pool.connection do |conn|
                expect(conn).to be_a(Moped::IO::Connection)
              end
              pool.reap
            end.value
          end
        end
      end
    end

    context "when accessing from a single thread" do

      context "when the pool is empty" do

        it "yields a new connection" do
          pool.connection do |conn|
            expect(conn).to be_a(Moped::IO::Connection)
          end
        end
      end

      context "when the pool is not empty" do

        let(:connection) do
          Moped::IO::Connection.new("127.0.0.1", 27017, 5)
        end

        context "when a connection exists for the thread" do

          let(:pinned) do
            pool.send(:pinned)
          end

          before do
            pinned[Thread.current.object_id] = connection
          end

          it "yields the connection" do
            pool.connection do |conn|
              expect(conn).to equal(connection)
            end
          end
        end
      end
    end
  end
end
