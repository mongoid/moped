require "spec_helper"

describe Moped::Protocol do
  let(:Protocol) { Moped::Protocol }

  let(:connection) do
    TCPSocket.new("localhost", 27017)
  end

  after do
    connection.close unless connection.closed?
  end

  describe "reply response flags" do
    let(:reply) do
      Protocol::Reply.deserialize(connection)
    end

    context "when get more is called with an invalid cursor" do
      let(:get_more) do
        Protocol::GetMore.new("moped-protocol", "suite", 0, 0)
      end

      specify "the cursor not found flag is set" do
        connection.write get_more
        reply.flags.should include :cursor_not_found
      end
    end

    context "when query generates an error" do
      let(:query) do
        Protocol::Query.new "moped-protocol", "people", { '$in' => 1 }, limit: -1
      end

      specify "the query failure flag is set" do
        connection.write query
        reply.flags.should eq [:query_failure]
      end
    end

    context "when mongod supports await data query option" do
      let(:query) do
        Protocol::Query.new "admin", "$cmd", { buildinfo: 1 }, limit: -1
      end

      specify "the await capable flag is set" do
        connection.write query

        if reply.documents[0]["version"] >= "1.6"
          reply.flags.should eq [:await_capable]
        else
          reply.flags.should eq []
        end
      end
    end

  end
end
