require "spec_helper"

describe Moped::WriteConcern do

  describe ".get" do

    context "when provided :unverified" do

      let(:concern) do
        described_class.get(:unverified)
      end

      it "returns an unverified write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Unverified)
      end
    end

    context "when provided 'unverified'" do

      let(:concern) do
        described_class.get("unverified")
      end

      it "returns an unverified write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Unverified)
      end
    end

    context "when provided :propagate" do

      let(:concern) do
        described_class.get(:propagate)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end

    context "when provided a hash" do

      let(:concern) do
        described_class.get(w: 3)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end
  end
end
