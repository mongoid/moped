require "spec_helper"

describe Moped::IO::Queue do

  describe "#pop" do

    let(:queue) do
      described_class.new
    end

    context "when the queue is empty" do

      it "returns nil" do
        expect(queue.pop(0.05)).to be_nil
      end

      pending "when another thread add an item to the queue" do

        let(:connection) do
          Moped::IO::Connection.new("127.0.0.1", 27017, 5)
        end

        let(:thread_one) do
          Thread.new do
            expect(queue.pop(2)).to eq(connection)
          end
        end

        let(:thread_two) do
          Thread.new do
            queue.push(connection)
          end
        end

        it "returns the newly added item" do
          thread_one.join(1)
          thread_two.join
        end
      end
    end

    context "when the queue is not empty" do

      let(:connection) do
        Moped::IO::Connection.new("127.0.0.1", 27017, 5)
      end

      before do
        queue.push(connection)
      end

      it "returns the next item in the queue" do
        expect(queue.pop(0.05)).to eq(connection)
      end
    end
  end

  describe "#push" do

    let(:queue) do
      described_class.new
    end

    let(:connection) do
      Moped::IO::Connection.new("127.0.0.1", 27017, 5)
    end

    before do
      queue.push(connection)
    end

    it "adds the item to the queue" do
      expect(queue.pop(0.05)).to eq(connection)
    end
  end

  describe "#size" do

    let(:queue) do
      described_class.new
    end

    let(:connection) do
      Moped::IO::Connection.new("127.0.0.1", 27017, 5)
    end

    before do
      queue.push(connection)
    end

    it "returns the number of items in the queue" do
      expect(queue.size).to eq(1)
    end
  end
end
