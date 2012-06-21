require "spec_helper"

describe Moped::Protocol::Message do

  let(:message_class) do
    Class.new do
      include Moped::Protocol::Message
    end
  end

  describe ".fields" do
    it "returns an array of defined fields" do
      message_class.cstring :full_collection_name
      message_class.int64 :cursor_id

      message_class.fields.should include(:full_collection_name, :cursor_id)
    end

    it "does not leak fields between messages" do
      message_class.int64 :cursor_id
      Class.new do
        include Moped::Protocol::Message
      end.fields.should_not include :cursor_id
    end
  end

  describe ".cstring" do
    let(:instance_methods) { message_class.instance_methods(false) }

    before do
      message_class.cstring :full_collection_name
    end

    it "defines an accessor method" do
      instance_methods.should include :full_collection_name=
    end

    it "defines a reader method" do
      instance_methods.should include :full_collection_name
    end

    it "defines a serialize method" do
      instance_methods.should include :serialize_full_collection_name
    end

    describe "#serialize" do
      let(:message) do
        message_class.new.tap do |message|
          message.full_collection_name = "moped.$cmd"
        end
      end

      it "appends the field value and a null byte to the buffer" do
        buffer = ""
        message.serialize_full_collection_name(buffer)
        buffer.should eq "moped.$cmd\u0000"
      end
    end
  end

  describe ".document" do
    let(:instance_methods) { message_class.instance_methods(false) }

    let(:message_class) do
      Class.new do
        include Moped::Protocol::Message
        document :selector
      end
    end

    it "defines an accessor method" do
      instance_methods.should include :selector=
    end

    it "defines a reader method" do
      instance_methods.should include :selector
    end

    it "defines a serialize method" do
      instance_methods.should include :serialize_selector
    end

    describe "#serialize" do
      let(:message) { message_class.new }
      let(:buffer) { "" }

      it "appends the serialized document to the buffer" do
        message.selector = { a: 1 }

        Moped::BSON::Document.should_receive(:serialize).
          with(message.selector, buffer)

        message.serialize_selector(buffer)
      end

      context "when optional and not present" do
        let(:message_class) do
          Class.new do
            include Moped::Protocol::Message
            document :selector, optional: true
          end
        end

        it "appends nothing" do
          message.serialize_selector(buffer)
          buffer.should eq ""
        end
      end

      context "when type is array" do
        let(:message_class) do
          Class.new do
            include Moped::Protocol::Message
            document :documents, type: :array
          end
        end

        it "appends each document" do
          message.documents = [{ a: 1 }, { b: 2 }]

          Moped::BSON::Document.should_receive(:serialize).
            with(message.documents[0], buffer)

          Moped::BSON::Document.should_receive(:serialize).
            with(message.documents[1], buffer)

          message.serialize_documents(buffer)
        end
      end

    end

  end

  describe ".flags" do
    let(:instance_methods) { message_class.instance_methods(false) }

    before do
      message_class.flags :flags, upsert: 2 ** 0,
                                  multi:  2 ** 1
    end

    it "defines an accessor method" do
      instance_methods.should include :flags=
    end

    it "defines a reader method" do
      instance_methods.should include :flags
    end

    it "defines a serialize method" do
      instance_methods.should include :serialize_flags
    end

    it "defaults to an empty array" do
      message_class.new.flags.should eq []
    end

    describe "accessor" do
      let(:message) { message_class.new }

      it "accepts an array of flags" do
        message.flags = [:upsert]
        message.flags.should eq [:upsert]
      end

      it "accepts an integer of bits" do
        message.flags = 1
        message.flags.should eq [:upsert]
      end
    end

    describe "#serialize" do
      let(:message) do
        message_class.new.tap do |message|
          message.flags = [:upsert]
        end
      end

      it "appends the value to the buffer" do
        buffer = ""
        message.serialize_flags(buffer)
        buffer.should eq [1].pack('l<')
      end
    end

    describe "#deserialize" do
      let(:message) { message_class.new }

      it "extracts the flags" do
        buffer = StringIO.new [1].pack('l<')
        message.deserialize_flags buffer
        message.flags.should eq [:upsert]
      end
    end
  end

  describe ".int32" do
    let(:instance_methods) { message_class.instance_methods(false) }

    before do
      message_class.int32 :request_id
    end

    it "defines an accessor method" do
      instance_methods.should include :request_id=
    end

    it "defines a reader method" do
      instance_methods.should include :request_id
    end

    it "defines a serialize method" do
      instance_methods.should include :serialize_request_id
    end

    it "defines a deserialize method" do
      instance_methods.should include :deserialize_request_id
    end

    describe "#accessor" do
      it "defaults to 0" do
        message_class.new.request_id.should eq 0
      end
    end

    describe "#serialize" do
      let(:message) do
        message_class.new.tap do |message|
          message.request_id = 32
        end
      end

      it "appends the value to the buffer" do
        buffer = ""
        message.serialize_request_id(buffer)
        buffer.should eq [32].pack('l<')
      end
    end

    describe "#deserialize" do
      let(:message) { message_class.new }

      it "sets the value from the buffer" do
        buffer = StringIO.new [32].pack('l<')
        message.deserialize_request_id(buffer)
        message.request_id.should eq 32
      end
    end
  end

  describe ".int64" do
    let(:instance_methods) { message_class.instance_methods(false) }

    before do
      message_class.int64 :cursor_id
    end

    it "defines an accessor method" do
      instance_methods.should include :cursor_id=
    end

    it "defines a reader method" do
      instance_methods.should include :cursor_id
    end

    it "defines a serialize method" do
      instance_methods.should include :serialize_cursor_id
    end

    it "defines a deserialize method" do
      instance_methods.should include :deserialize_cursor_id
    end

    describe "#accessor" do
      it "defaults to 0" do
        message_class.new.cursor_id.should eq 0
      end
    end

    describe "#serialize" do
      context "when no type is provided" do
        let(:message) do
          message_class.new.tap do |message|
            message.cursor_id = 10
          end
        end

        it "appends the field value and a null byte to the buffer" do
          buffer = ""
          message.serialize_cursor_id(buffer)
          buffer.should eq [message.cursor_id].pack('q<')
        end
      end

      context "when type is array" do
        let(:message_class) do
          Class.new do
            include Moped::Protocol::Message
            int64 :cursor_ids, type: :array
          end
        end

        let(:message) do
          message_class.new
        end

        context "and value is blank" do
          it "does not modify the buffer" do
            buffer = ""
            message.serialize_cursor_ids(buffer)
            buffer.should eq ""
          end
        end

        context "and value is set" do
          it "appends each value to the buffer" do
            buffer = ""
            message.cursor_ids = [1, 2, 3]
            message.serialize_cursor_ids(buffer)
            buffer.should eq [1, 2, 3].pack("q3<")
          end
        end

      end
    end

    describe "#deserialize" do
      let(:message) { message_class.new }

      context "when no type is provided" do
        it "sets the value from the buffer" do
          buffer = StringIO.new [32].pack('q<')
          message.deserialize_cursor_id(buffer)
          message.cursor_id.should eq 32
        end
      end

      context "when type is array" do
        let(:message_class) do
          Class.new do
            include Moped::Protocol::Message

            int64 :cursor_ids, type: :array
          end
        end

        it "raises NotImplementedError" do
          buffer = StringIO.new [1, 2, 3].pack('q*<')
          lambda { message.deserialize_cursor_ids(buffer) }.should raise_error NotImplementedError
        end
      end
    end
  end

  describe "#inspect" do
    let(:message_class) do
      Class.new do
        include Moped::Protocol::Message
        int32    :length
        flags    :flags, remove_single: 2 ** 0
        finalize
      end
    end

    let(:message) { message_class.new }

    it "does not attempt to serialize the message" do
      message.inspect.should_not eq message.to_s
    end
  end

  describe "#serialize" do
    let(:message_class) do
      Class.new do
        include Moped::Protocol::Message
        int32    :length
        int64    :cursor_id
        cstring  :collection
        flags    :flags, remove_single: 2 ** 0
        document :selector
        finalize
      end
    end

    let(:message) { message_class.new }
    let(:buffer) { "" }

    it "is aliased to #to_s" do
      message.collection = "db.$cmd"
      message.selector = {}
      message.serialize.should eq message.to_s
    end

    it "serializes all fields and returns the buffer" do
      message_class.fields.each do |field|
        message.should_receive(:"serialize_#{field}")
          .at_least(1).with(buffer).and_return("")
      end

      message.serialize(buffer).should eql buffer
    end

    it "sets the length to the length of the buffer" do
      message_class.fields.each do |field|
        message.stub(:"serialize_#{field}" => "")
      end

      message.should_receive(:length=).with(buffer.length)
      message.serialize(buffer)
    end

    it "prepends the buffer with the new length" do
      message_class.fields.each do |field|
        message.stub(:"serialize_#{field}") unless field == :length
      end

      message.serialize(buffer)

      buffer[0, 4].should eq message.serialize_length("")
    end

    context "when the buffer already contains data" do
      before do
        message.collection = "admin.$cmd"
        message.selector = {}
      end

      it "appends the data" do
        serialized_data = message.serialize

        buffer = "existing data"
        message.serialize(buffer)
        buffer.should eq "existing data" + serialized_data
      end
    end
  end

end
