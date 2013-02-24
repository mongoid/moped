require "spec_helper"

describe Moped::Ring do

  let(:one) do
    Moped::Node.new("127.0.0.1:27017")
  end

  let(:two) do
    Moped::Node.new("127.0.0.1:27018")
  end

  let(:three) do
    Moped::Node.new("127.0.0.1:27019")
  end

  describe "#add" do

    let(:ring) do
      described_class.new([ one ])
    end

    context "when provided a single node" do

      context "when the node is unique" do

        before do
          ring.add(two)
        end

        it "adds the node to the ring" do
          expect(ring.nodes).to eq([ one, two ])
        end
      end

      context "when the node is not unique" do

        before do
          ring.add(one)
        end

        it "does not add the node to the ring" do
          expect(ring.nodes).to eq([ one ])
        end
      end
    end

    context "when provided multiple nodes" do

      context "when the nodes are unique" do

        before do
          ring.add(two, three)
        end

        it "adds the node to the ring" do
          expect(ring.nodes).to eq([ one, two, three ])
        end
      end

      context "when the nodes are not all unique" do

        before do
          ring.add(one, two)
        end

        it "does not add the node to the ring" do
          expect(ring.nodes).to eq([ one, two ])
        end
      end
    end

    context "when provided an array of nodes" do

      context "when the nodes are unique" do

        before do
          ring.add([ two, three ])
        end

        it "adds the node to the ring" do
          expect(ring.nodes).to eq([ one, two, three ])
        end
      end

      context "when the nodes are not all unique" do

        before do
          ring.add([ one, two ])
        end

        it "does not add the node to the ring" do
          expect(ring.nodes).to eq([ one, two ])
        end
      end
    end

    context "when provided nil" do

      before do
        ring.add(nil)
      end

      it "does not alter the ring" do
        expect(ring.nodes).to eq([ one ])
      end
    end

    context "when provided multple nil values" do

      before do
        ring.add(nil, nil, nil)
      end

      it "does not alter the ring" do
        expect(ring.nodes).to eq([ one ])
      end
    end
  end

  describe "#next_primary" do

    context "when no nodes are primary (big trouble)" do

      before do
        one.instance_variable_set(:@primary, false)
        two.instance_variable_set(:@primary, false)
        three.instance_variable_set(:@primary, false)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns the next primary in the ring" do
        expect(ring.next_primary).to be_nil
      end
    end

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
        expect(ring.next_primary).to eq(two)
        expect(ring.next_primary).to eq(three)
      end

      context "when cycling full the entire list" do

        before do
          3.times { ring.next_primary }
        end

        it "loops back through the beginning" do
          expect(ring.next_primary).to eq(two)
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
        expect(ring.next_secondary).to eq(two)
        expect(ring.next_secondary).to eq(three)
      end

      context "when cycling full the entire list" do

        before do
          3.times { ring.next_secondary }
        end

        it "loops back through the beginning" do
          expect(ring.next_secondary).to eq(two)
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

    context "when no node is secondary (bad call)" do

      before do
        one.instance_variable_set(:@secondary, false)
        two.instance_variable_set(:@secondary, false)
        three.instance_variable_set(:@secondary, false)
      end

      let(:ring) do
        described_class.new([ one, two, three ])
      end

      it "returns nil" do
        expect(ring.next_secondary).to be_nil
      end
    end
  end
end
