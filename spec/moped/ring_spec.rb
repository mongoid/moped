require "spec_helper"

describe Moped::Ring do

  let(:one) do
    Moped::Node.new("127.0.0.1:27017")
  end

  let(:two) do
    Moped::Node.new("127.0.0.1:27017")
  end

  let(:three) do
    Moped::Node.new("127.0.0.1:27017")
  end

  describe "#next_primary" do

    context "when all nodes are primary (multiple mongos)" do

      before do
        one.instance_variable_set(:@primary, true)
        two.instance_variable_set(:@primary, true)
        three.instance_variable_set(:@primary, true)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns the next primary in the ring" do
        expect(ring.next_primary).to eq(one)
        expect(ring.next_primary).to eq(two)
      end

      context "when cycling full the entire list" do

        before do
          3.times { ring.next_primary }
        end

        it "loops back through the beginning" do
          expect(ring.next_primary).to eq(one)
        end
      end
    end

    context "when one node is primary (replica set)" do

      before do
        one.instance_variable_set(:@primary, false)
        two.instance_variable_set(:@primary, true)
        three.instance_variable_set(:@primary, false)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns the only primary in the ring" do
        5.times { expect(ring.next_primary).to eq(two) }
      end
    end
  end

  describe "#next_secondary" do

    context "when all nodes are secondary (replica set reconfiguring)" do

      before do
        one.instance_variable_set(:@secondary, true)
        two.instance_variable_set(:@secondary, true)
        three.instance_variable_set(:@secondary, true)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns the next secondary in the ring" do
        expect(ring.next_secondary).to eq(one)
        expect(ring.next_secondary).to eq(two)
      end

      context "when cycling full the entire list" do

        before do
          3.times { ring.next_secondary }
        end

        it "loops back through the beginning" do
          expect(ring.next_secondary).to eq(one)
        end
      end
    end

    context "when multiple nodes are secondary (replica set)" do

      before do
        one.instance_variable_set(:@secondary, false)
        two.instance_variable_set(:@secondary, true)
        three.instance_variable_set(:@secondary, true)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns the next secondary in the ring" do
        expect(ring.next_secondary).to eq(two)
        expect(ring.next_secondary).to eq(three)
      end
    end

    context "when one node is secondary (replica set + arbiter)" do

      before do
        one.instance_variable_set(:@secondary, false)
        two.instance_variable_set(:@secondary, true)
        three.instance_variable_set(:@secondary, false)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns the only secondary in the ring" do
        5.times { expect(ring.next_secondary).to eq(two) }
      end
    end
  end
end
