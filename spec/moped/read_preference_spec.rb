require "spec_helper"

describe Moped::ReadPreference do

  describe ".get" do

    context "when asking for :nearest" do

      let(:preference) do
        described_class.get(:nearest)
      end

      let(:nearest) do
        Moped::ReadPreference::Nearest
      end

      it "returns the nearest read preference" do
        expect(preference).to eq(nearest)
      end
    end
  end
end
