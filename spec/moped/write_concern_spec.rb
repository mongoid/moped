require "spec_helper"

describe Moped::WriteConcern do

  describe ".get" do

    context "when provided 0" do

      let(:concern) do
        described_class.get(w: 0)
      end

      it "returns an unverified write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Unverified)
      end
    end

    context "when provided -1" do

      let(:concern) do
        described_class.get(w: -1)
      end

      it "returns an unverified write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Unverified)
      end
    end

    context "when provided 1" do

      let(:concern) do
        described_class.get(w: 1)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end

    context "when provided a number greater than 1" do

      let(:concern) do
        described_class.get(w: 3)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end

    context "when provided :majority" do

      let(:concern) do
        described_class.get(w: :majority)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end

    context "when providing fsync" do

      let(:concern) do
        described_class.get(fsync: true)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end

    context "when providing wtimeout" do

      let(:concern) do
        described_class.get(wtimeout: 100)
      end

      it "returns a propagating write concern" do
        expect(concern).to be_a(Moped::WriteConcern::Propagate)
      end
    end
  end
end
