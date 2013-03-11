require "spec_helper"

describe Moped::WriteConcern::Unverified do

  describe "#command" do

    let(:concern) do
      described_class.new
    end

    let(:database) do
      "moped_test"
    end

    let(:command) do
      concern.command(database)
    end

    it "returns nil" do
      expect(command).to be_nil
    end
  end
end
