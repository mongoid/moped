require "spec_helper"

describe Moped::ReadPreference::Nearest do

  describe "#name" do

    let(:preference) do
      described_class.new
    end

    it "returns nearest" do
      expect(preference.name).to eq(:nearest)
    end
  end

  pending "#select"
end
