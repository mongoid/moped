require "spec_helper"

describe Moped::Connection::Pool do

  describe "#checkin" do

    context "when connections exist in the pool" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017, pool_size: 2)
      end

      let(:pinned) do
        pool.send(:pinned)
      end

      let(:unpinned) do
        pool.send(:unpinned)
      end

      context "when a pinned connection exists for the thread" do

        let(:connection) do
          pool.checkout
        end

        before do
          pool.checkin(connection)
        end

        it "keeps the connection pinned" do
          expect(pinned[Thread.current.object_id]).to equal(connection)
        end

        it "does not modify the unpinned connections" do
          expect(unpinned.size).to eq(1)
        end

        it "expires the connection" do
          expect(connection).to be_expired
        end

        it "keeps the pool size" do
          expect(pool.size).to eq(2)
        end
      end
    end
  end

  describe "#checkout" do

    shared_examples_for "a pool with an available connection on the current thread" do

      let(:pinned) do
        pool.send(:pinned)
      end

      it "creates a new connection" do
        expect(connection).to be_a(Moped::Connection)
      end

      it "sets the connection last use time" do
        expect(connection.last_use).to be_within(1).of(Time.now)
      end

      it "pins the connection to the current thread" do
        expect(pinned[Thread.current.object_id]).to be_a(Moped::Connection)
      end
    end

    context "when no connections exist in the pool" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017, pool_size: 2)
      end

      let!(:connection) do
        pool.checkout
      end

      it_behaves_like "a pool with an available connection on the current thread"

      it "updates the pool size" do
        expect(pool.size).to eq(2)
      end
    end

    context "when connections exist in the pool" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017, pool_size: 2)
      end

      context "when a connection exists for the thread id" do

        let!(:existing) do
          pool.checkout
        end

        context "when the connection is not in use" do

          before do
            pool.checkin(existing)
          end

          it "returns the connection" do
            expect(pool.checkout).to equal(existing)
          end
        end

        context "when the connection is in use" do

          it "raises an error" do
            expect {
              pool.checkout
            }.to raise_error(Moped::Errors::ConnectionInUse)
          end
        end
      end

      context "when a connection exists for another thread id" do

        context "when the pool is not saturated" do

          before do
            Thread.new do
              pool.checkout
            end.join
          end

          let!(:connection) do
            pool.checkout
          end

          it_behaves_like "a pool with an available connection on the current thread"

          it "updates the pool size" do
            expect(pool.size).to eq(2)
          end
        end

        context "when the pool is saturated" do

          context "when reaping frees new connections" do

            let!(:thread_one) do
              Thread.new do
                pool.checkout
              end
            end

            let!(:thread_two) do
              Thread.new do
                pool.checkout
              end
            end

            before do
              thread_one.join
              thread_two.join
              thread_one.kill
            end

            let!(:connection) do
              pool.checkout
            end

            it_behaves_like "a pool with an available connection on the current thread"

            it "does not change the pool size" do
              expect(pool.size).to eq(2)
            end
          end

          context "when reaping does not free any new connections" do

            let!(:thread_one) do
              Thread.new do
                pool.checkout
              end
            end

            let!(:thread_two) do
              Thread.new do
                pool.checkout
                pool.checkout
              end
            end

            before do
              thread_one.join
            end

            it "raises an error" do
              expect {
                thread_two.join
              }.to raise_error(Moped::Errors::ConnectionInUse)
            end
          end
        end
      end
    end
  end

  describe "#initialize" do

    let(:pool) do
      described_class.new("127.0.0.1", 27017, pool_size: 2)
    end

    it "instantiates all the connections" do
      expect(pool.size).to eq(2)
    end
  end

  describe "#max_size" do

    context "when the max_size option is provided" do

      let(:pool) do
        described_class.new("127.0.0.1", 27017, pool_size: 2)
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
