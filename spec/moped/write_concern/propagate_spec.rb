require "spec_helper"

describe Moped::WriteConcern::Propagate do

  describe "#command" do

    let(:concern) do
      described_class.new(:propagate)
    end

    let(:database) do
      "moped_test"
    end

    let(:command) do
      concern.command(database)
    end

    it "returns the gle command" do
      expect(command.selector).to eq(getlasterror: 1)
    end
  end

  describe "#initialize" do

    context "when the concern is :propagate" do

      let(:concern) do
        described_class.new(:propagate)
      end

      it "sets the standard gle operation" do
        expect(concern.operation).to eq(getlasterror: 1)
      end
    end

    context "when the concern is an options hash" do

      let(:concern) do
        described_class.new(w: 3)
      end

      it "merges the options into the gle" do
        expect(concern.operation).to eq(getlasterror: 1, w: 3)
      end
    end
  end
end
