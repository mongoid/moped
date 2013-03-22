require "spec_helper"
require "yaml"

describe Moped::BSON::ObjectId do

  let(:bytes) do
    [78, 77, 102, 52, 59, 57, 182, 132, 7, 0, 0, 1].pack("C12")
  end

  describe "#===" do

    let(:object_id) do
      described_class.new
    end

    context "when comparing with another object id" do

      context "when the data is equal" do

        let(:other) do
          described_class.from_string(object_id.to_s)
        end

        it "returns true" do
          (object_id === other).should be_true
        end
      end

      context "when the data is not equal" do

        let(:other) do
          described_class.new
        end

        it "returns false" do
          (object_id === other).should be_false
        end
      end
    end

    context "when comparing to an object id class" do

      it "returns false" do
        (object_id === Moped::BSON::ObjectId).should be_false
      end
    end

    context "when comparing with a string" do

      context "when the data is equal" do

        let(:other) do
          object_id.to_s
        end

        it "returns true" do
          (object_id === other).should be_true
        end
      end

      context "when the data is not equal" do

        let(:other) do
          described_class.new.to_s
        end

        it "returns false" do
          (object_id === other).should be_false
        end
      end
    end

    context "when comparing with a non string or object id" do

      it "returns false" do
        (object_id === "test").should be_false
      end
    end

    context "when comparing with a non object id class" do

      it "returns false" do
        (object_id === String).should be_false
      end
    end
  end

  describe "ordering" do

    let(:first) do
      described_class.from_time(Time.new(2012, 1, 1))
    end

    let(:last) do
      described_class.from_time(Time.new(2012, 1, 30))
    end

    specify "first is less than last" do
      first.should be < last
    end

    specify "last is greater than first" do
      last.should be > first
    end
  end

  describe "unmarshalling" do

    let(:marshal_data) do
      Marshal.dump(described_class.from_data(bytes))
    end

    it "does not attempt to repair the id" do
      id = Marshal.load(marshal_data)
      id.should_receive(:repair!).never
      id.data
    end

    context "when the object id was marshalled before a custom marshal strategy was added" do
      let(:marshal_data) do
        "\x04\bo:\x1AMoped::BSON::ObjectId\x06:\n@data\"\x11NMf4;9\xB6\x84\a\x00\x00\x01"
      end

      it "repairs the object id" do
        id = Marshal.load(marshal_data)
        id.should_receive :repair!
        id.data
      end
    end

    context "when the object id was marshalled in the mongo-ruby-driver format" do
      let(:marshal_data) do
        "\x04\bo:\x1AMoped::BSON::ObjectId\x06:\n@data[\x11iSiRiki9i@i>i\x01\xB6i\x01\x84i\fi\x00i\x00i\x06"
      end

      it "repairs the object id" do
        id = Marshal.load(marshal_data)
        id.should_receive :repair!
        id.data
      end
    end
  end

  describe ".from_string" do

    context "when the string is valid" do

      it "initializes with the string's bytes" do
        described_class.should_receive(:from_data).with(bytes)
        described_class.from_string "4e4d66343b39b68407000001"
      end
    end

    context "when the string is not valid" do

      it "raises an error" do
        expect {
          described_class.from_string("asadsf")
        }.to raise_error(Moped::Errors::InvalidObjectId)
      end
    end
  end

  describe ".legal?" do

    context "when the string is too short to be an object id" do
      it "returns false" do
        described_class.legal?("a" * 23).should be_false
      end
    end

    context "when the string contains invalid hex characters" do
      it "returns false" do
        described_class.legal?("y" + "a" * 23).should be_false
      end
    end

    context "when the string is a valid object id" do
      it "returns true" do
        described_class.legal?("a" * 24).should be_true
      end
    end

    context "when checking against another object id" do

      let(:object_id) do
        described_class.new
      end

      it "returns true" do
        described_class.legal?(object_id).should be_true
      end
    end
  end

  describe ".from_time" do

    context "when no unique option is provided" do

      let(:time) do
        Time.at((Time.now.utc - 64800).to_i).utc
      end

      it "sets the generation time" do
        described_class.from_time(time).generation_time.should eq(time)
      end

      it "does not include process or sequence information" do
        id = described_class.from_time(Time.now)
        id.to_s.should =~ /\A\h{8}0{16}\Z/
      end
    end

    context "when a unique option is provided" do

      let(:time) do
        Time.at((Time.now.utc - 64800).to_i).utc
      end

      let(:object_id) do
        described_class.from_time(time, unique: true)
      end

      let(:non_unique) do
        described_class.from_time(time, unique: true)
      end

      it "creates a new unique object id" do
        object_id.should_not eq(non_unique)
      end
    end
  end

  describe "#initialize" do
    context "with no data" do
      it "increments the id on each call" do
        described_class.new.should_not eq described_class.new
      end

      it "increments the id safely across threads" do
        ids = 2.times.map { Thread.new { described_class.new } }
        ids[0].value.should_not eq ids[1].value
      end
    end
  end

  describe "#==" do

    context "when data is identical" do
      it "returns true" do
        described_class.from_data(bytes).should == described_class.from_data(bytes)
      end
    end

    context "when other is not an object id" do
      it "returns false" do
        described_class.new.should_not == nil
      end
    end

  end

  describe "#eql?" do

    context "when data is identical" do
      it "returns true" do
        described_class.from_data(bytes).should eql described_class.from_data(bytes)
      end
    end

    context "when other is not an object id" do
      it "returns false" do
        described_class.new.should_not eql nil
      end
    end

  end

  describe "#hash" do

    context "when data is identical" do
      it "returns the same hash" do
        described_class.from_data(bytes).hash.should eq described_class.from_data(bytes).hash
      end
    end

    context "when other is not an object id" do
      it "returns a different hash" do
        described_class.new.hash.should_not eql described_class.new.hash
      end
    end

  end

  describe "#to_s" do

    it "returns a hex string representation of the id" do
      described_class.from_data(bytes).to_s.should eq(
        "4e4d66343b39b68407000001"
      )
    end

    it "returns the string in UTF-8" do
      described_class.from_data(bytes).to_s.encoding.should eq(
        Moped::BSON::UTF8_ENCODING
      )
    end

    it "converts to a readable yaml string" do
      YAML.dump(described_class.from_data(bytes).to_s).should include(
        "4e4d66343b39b68407000001"
      )
    end
  end

  describe "#inspect" do

    it "returns a sane representation of the id" do
      described_class.from_data(bytes).inspect.should eq(
        '"4e4d66343b39b68407000001"'
      )
    end
  end

  describe "#to_json" do

    it "returns a json representation of the id" do
      described_class.from_data(bytes).to_json.should eq(
        '{"$oid": "4e4d66343b39b68407000001"}'
      )
    end
  end

  describe "#repair!" do

    let(:id) { described_class.allocate }

    context "when the data is a 12-element array" do

      it "sets the id's data to the byte string" do
        id.send(:repair!, bytes.unpack("C*"))
        id.data.should eq bytes
      end
    end

    context "when the data is a 12-element byte string" do

      it "sets the id's data to the byte string" do
        id.send(:repair!, bytes)
        id.data.should eq bytes
      end
    end

    context "when the data is in another format" do

      it "raises a type error" do
        lambda do
          id.send(:repair!, bytes.unpack("C11"))
        end.should raise_exception(TypeError)
      end
    end
  end
end
