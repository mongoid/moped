require "spec_helper"

describe Moped::ReadPreference do

  describe ".get" do

    context "when asking for :nearest" do

      let(:preference) do
        described_class.get(:nearest)
      end

      it "returns the nearest read preference" do
        expect(preference).to be_a(Moped::ReadPreference::Nearest)
      end
    end

    context "when asking for 'nearest'" do

      let(:preference) do
        described_class.get("nearest")
      end

      it "returns the nearest read preference" do
        expect(preference).to be_a(Moped::ReadPreference::Nearest)
      end
    end

    context "when asking for :primary" do

      let(:preference) do
        described_class.get(:primary)
      end

      it "returns the primary read preference" do
        expect(preference).to be_a(Moped::ReadPreference::Primary)
      end
    end

    context "when asking for :primary_preferred" do

      let(:preference) do
        described_class.get(:primary_preferred)
      end

      it "returns the primary preferred read preference" do
        expect(preference).to be_a(Moped::ReadPreference::PrimaryPreferred)
      end
    end

    context "when asking for :secondary" do

      let(:preference) do
        described_class.get(:secondary)
      end

      it "returns the secondary read preference" do
        expect(preference).to be_a(Moped::ReadPreference::Secondary)
      end
    end

    context "when asking for :secondary_preferred" do

      let(:preference) do
        described_class.get(:secondary_preferred)
      end

      it "returns the secondary preferred read preference" do
        expect(preference).to be_a(Moped::ReadPreference::SecondaryPreferred)
      end
    end
  end
end
