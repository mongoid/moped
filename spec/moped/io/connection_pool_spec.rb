require "spec_helper"

describe Moped::IO::ConnectionPool do

  describe "#initialize" do

    context "when provided no options" do

      let(:pool) do
        described_class.new
      end

      it "defaults the max size to 5" do
        expect(pool.max_size).to eq(5)
      end
    end

    context "when provided options" do

      context "when provided a max size" do

        let(:pool) do
          described_class.new(max_size: 2)
        end

        it "set the max size to the provided value" do
          expect(pool.max_size).to eq(2)
        end

        it "sets the options" do
          expect(pool.options).to eq(max_size: 2)
        end
      end
    end
  end
end
