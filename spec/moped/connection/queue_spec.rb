require "spec_helper"

describe Moped::Connection::Queue do

  describe "#empty?" do

    let(:queue) do
      described_class.new(1, 0.5) do
        Moped::Connection.new("127.0.0.1", 27017, 5)
      end
    end

    context "when the queue has connections" do

      it "returns false" do
        expect(queue).to_not be_empty
      end
    end

    context "when the queue has no connections" do

      before do
        queue.shift
      end

      it "returns true" do
        expect(queue).to be_empty
      end
    end
  end

  describe "#initialize" do

    let(:queue) do
      described_class.new(2, 0.5) do
        Moped::Connection.new("127.0.0.1", 27017, 5)
      end
    end

    it "yields to the block n times" do
      expect(queue.size).to eq(2)
    end
  end

  describe "#shift" do

    let(:queue) do
      described_class.new(1, 0.5) do
        Moped::Connection.new("127.0.0.1", 27017, 5)
      end
    end

    context "when a connection is available" do

      let(:popped) do
        queue.shift
      end

      it "returns the connection" do
        expect(popped).to be_a(Moped::Connection)
      end
    end

    context "when a connection is not available" do

      before do
        queue.shift
      end

      context "when a connection is pushed in the timeout period" do

        let(:connection) do
          Moped::Connection.new("127.0.0.1", 27017, 5)
        end

        before do
          Thread.new do
            sleep(1)
            queue.push(connection)
          end.join
        end

        it "returns the connection" do
          expect(queue.shift).to equal(connection)
        end
      end

      context "when no connection is pushed in the timeout period" do

        it "raises an error" do
          expect { queue.shift }.to raise_error(Timeout::Error)
        end
      end
    end
  end

  describe "#push" do

    let(:connection) do
      Moped::Connection.new("127.0.0.1", 27017, 5)
    end

    let(:queue) do
      described_class.new(1, 0.5) do
        Moped::Connection.new("127.0.0.1", 27017, 5)
      end
    end

    before do
      queue.push(connection)
    end

    it "adds the connection to the queue" do
      expect(queue.size).to eq(2)
    end
  end

  describe "#size" do

    let(:queue) do
      described_class.new(1, 0.5) do
        Moped::Connection.new("127.0.0.1", 27017, 5)
      end
    end

    it "returns the number of connections" do
      expect(queue.size).to eq(1)
    end
  end
end
