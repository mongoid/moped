require "spec_helper"

describe Moped::Server do

  describe "#initialize" do
    let(:server) do
      described_class.new("localhost:123")
    end

    it "stores the original address" do
      server.address.should eq "localhost:123"
    end

    it "stores the resolved address" do
      server.resolved_address.should eql "127.0.0.1:123"
    end

    it "stores the resolved ip" do
      server.ip_address.should eq "127.0.0.1"
    end

    it "stores the port" do
      server.port.should eq 123
    end
  end

  describe "==" do
    context "when ip and port are the same" do
      it "returns true" do
        described_class.new("127.0.0.1:999").should eq \
          described_class.new("localhost:999")
      end
    end

    context "when ip and port are different" do
      it "returns false" do
        described_class.new("127.0.0.1:1000").should_not eq \
          described_class.new("localhost:999")
      end
    end

    context "when other is not a server" do
      it "returns false" do
        described_class.new("127.0.0.1:999").should_not eq 1
      end
    end
  end

  context "when added to a set" do
    let(:set) { Set.new }

    context "and ip and port are the same" do
      it "does not add both servers" do
        set << described_class.new("127.0.0.1:1000")
        set << described_class.new("127.0.0.1:1000")

        set.length.should eq 1
      end

      context "and the original address is different" do
        it "does not add both servers" do
          set << described_class.new("localhost:1000")
          set << described_class.new("127.0.0.1:1000")

          set.length.should eq 1
        end
      end
    end

    context "and ip and port are different" do
      it "adds both servers" do
        set << described_class.new("127.0.0.1:1000")
        set << described_class.new("127.0.0.1:2000")

        set.length.should eq 2
      end
    end
  end

end
