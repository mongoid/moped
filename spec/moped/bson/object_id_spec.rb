require "spec_helper"

describe Moped::BSON::ObjectId do
  let(:bytes) do
    [78, 77, 102, 52, 59, 57, 182, 132, 7, 0, 0, 1]
  end

  describe ".from_string" do

    context "when the string is valid" do

      it "initializes with the strings bytes" do
        Moped::BSON::ObjectId.should_receive(:new).with(bytes)
        Moped::BSON::ObjectId.from_string "4e4d66343b39b68407000001"
      end
    end

    context "when the string is not valid" do

      it "raises an error" do
        expect {
          Moped::BSON::ObjectId.from_string("asadsf")
        }.to raise_error(Moped::Errors::InvalidObjectId)
      end
    end
  end

  describe ".legal?" do

    context "when the string is too short to be an object id" do
      it "returns false" do
        Moped::BSON::ObjectId.legal?("a" * 23).should be_false
      end
    end

    context "when the string contains invalid hex characters" do
      it "returns false" do
        Moped::BSON::ObjectId.legal?("y" + "a" * 23).should be_false
      end
    end

    context "when the string is a valid object id" do
      it "returns true" do
        Moped::BSON::ObjectId.legal?("a" * 24).should be_true
      end
    end

  end

  describe "#initialize" do

    context "with data" do
      it "sets the object id's data" do
        Moped::BSON::ObjectId.new(bytes).data.should == bytes
      end
    end

    context "with no data" do
      it "increments the id on each call" do
        Moped::BSON::ObjectId.new.should_not eq Moped::BSON::ObjectId.new
      end

      it "increments the id safely across threads" do
        ids = 2.times.map { Thread.new { Moped::BSON::ObjectId.new } }
        ids[0].value.should_not eq ids[1].value
      end
    end

    context "with a time" do
      it "sets the generation time" do
        time = Time.at((Time.now.utc - 64800).to_i).utc
        Moped::BSON::ObjectId.new(nil, time).generation_time.should == time
      end
    end

  end

  describe "#==" do

    context "when data is identical" do
      it "returns true" do
        Moped::BSON::ObjectId.new(bytes).should == Moped::BSON::ObjectId.new(bytes)
      end
    end

    context "when other is not an object id" do
      it "returns false" do
        Moped::BSON::ObjectId.new.should_not == nil
      end
    end

  end

  describe "#eql?" do

    context "when data is identical" do
      it "returns true" do
        Moped::BSON::ObjectId.new(bytes).should eql Moped::BSON::ObjectId.new(bytes)
      end
    end

    context "when other is not an object id" do
      it "returns false" do
        Moped::BSON::ObjectId.new.should_not eql nil
      end
    end

  end

  describe "#hash" do

    context "when data is identical" do
      it "returns the same hash" do
        Moped::BSON::ObjectId.new(bytes).hash.should eq Moped::BSON::ObjectId.new(bytes).hash
      end
    end

    context "when other is not an object id" do
      it "returns a different hash" do
        Moped::BSON::ObjectId.new.hash.should_not eql Moped::BSON::ObjectId.new.hash
      end
    end

  end

  describe "#to_s" do

    it "returns a hex string representation of the id" do
      Moped::BSON::ObjectId.new(bytes).to_s.should eq "4e4d66343b39b68407000001"
    end

  end

end
