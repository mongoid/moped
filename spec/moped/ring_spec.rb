require "spec_helper"

describe Moped::Ring do

  describe "#next" do

    let(:one) do
      "one"
    end

    let(:two) do
      "two"
    end

    let(:three) do
      "three"
    end

    let(:four) do
      "four"
    end

    let(:ring) do
      described_class.new([ one, two, three, four ])
    end

    it "returns the next item in the ring" do
      expect(ring.next).to eq(one)
      expect(ring.next).to eq(two)
    end

    context "when cycling full the entire list" do

      before do
        4.times { ring.next }
      end

      it "loops back through the beginning" do
        expect(ring.next).to eq(one)
      end
    end
  end
end
