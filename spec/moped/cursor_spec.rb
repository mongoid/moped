require "spec_helper"

describe Moped::Cursor do
  let(:socket) { mock Moped::Socket }
  let(:query_operation) { Moped::Protocol::Query.allocate }
  let(:cursor) { Moped::Cursor.new(socket, query_operation) }

  describe "#initialize" do
    it "stores the socket" do
      cursor.socket.should eq socket
    end

    it "stores a copy of the query operation" do
      query_operation.should_receive(:dup).and_return(query_operation)
      cursor.query_op.should eq query_operation
    end

    it "sets the query operation's callback" do
      cursor.query_op.callback.should eq cursor.callback
    end

    describe "the get_more operation" do
      it "inherits the query's database" do
        cursor.get_more_op.database.should eq query_operation.database
      end

      it "inherits the query's collection" do
        cursor.get_more_op.collection.should eq query_operation.collection
      end

      it "inherits the query's limit" do
        cursor.get_more_op.limit.should eq query_operation.limit
      end

      it "has the cursor's callback" do
        cursor.get_more_op.callback.should eq cursor.callback
      end
    end
  end

  describe "#each" do
    let(:cursor) { Moped::Cursor.allocate }

    it "yields all documents in the cursor" do
      cursor.stub(:next).and_return(1, 2, nil)
      docs = []
      cursor.each do |doc|
        docs << doc
      end
      docs.should eq [1, 2]
    end
  end
end
