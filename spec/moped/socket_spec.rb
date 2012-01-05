require "spec_helper"

describe Moped::Socket do

  let!(:server) do
    TCPServer.new "127.0.0.1", 0
  end

  let(:socket) do
    described_class.new "127.0.0.1", server.addr[1]
  end

  let(:connection) {
    socket.connection
  }

  before do
    socket.connect
  end

  after do
    connection.close unless connection.closed?
    server.close unless server.closed?
  end

  describe "#initialize" do
    it "stores the host of the server" do
      socket.host.should eq "127.0.0.1"
    end

    it "stores the port of the server" do
      socket.port.should eq server.addr[1]
    end

    it "connects to the server" do
      socket.connection.should_not be_closed
    end
  end

  describe "#execute" do
    let(:query) { Crutches::Protocol::Query.new(:crutches, :test, {}) }

    context "when competing threads attempt to query" do
      let(:messages) do
        10.times.map do |i|
          Crutches::Protocol::Insert.new(:crutches, :test, {}).tap do |query|
            query.stub(request_id: 123)
          end
        end
      end

      it "never issues a partial write" do
        socket

        threads = 10.times.map do |i|
          Thread.new do
            Thread.current.abort_on_exception = true
            socket.execute messages[i]
          end
        end

        threads.each &:join

        sock = server.accept
        data = sock.read messages.join.length

        messages.each do |message|
          fail "server received partial write" unless data.include? message.serialize
        end
      end
    end
  end

  describe "#parse_reply" do
    let(:raw) do
      Crutches::Protocol::Reply.allocate.tap do |reply|
        reply.request_id = 1
        reply.response_to = 1
        reply.op_code = 1
        reply.flags = [:await_capable]
        reply.offset = 4
        reply.count = 1
        reply.documents = [{"name" => "John"}]
      end.serialize
    end

    let(:reply) do
      socket.parse_reply(raw.length, raw[4..-1])
    end

    it "sets the length" do
      reply.length.should eq raw.length
    end

    it "sets the response_to" do
      reply.response_to.should eq 1
    end

    it "sets the request id" do
      reply.request_id.should eq 1
    end

    it "sets the flags" do
      reply.flags.should eq [:await_capable]
    end

    it "sets the offset" do
      reply.offset.should eq 4
    end

    it "sets the count" do
      reply.count.should eq 1
    end

    it "sets the documents" do
      reply.documents.should eq [{"name" => "John"}]
    end
  end

  describe "#simple_query" do
    let(:query) { Crutches::Protocol::Query.allocate }
    let(:reply) do
      Crutches::Protocol::Reply.allocate.tap do |reply|
        reply.documents = [{a: 1}]
      end
    end

    it "returns the document" do
      socket.stub(execute: reply)
      socket.simple_query(query).should eq(a: 1)
    end

    context "when execute fails" do
      it "raises the exception" do
        exception = RuntimeError.new

        socket.stub(:execute) do |query|
          raise exception
        end

        lambda { socket.simple_query(query) }.
          should raise_exception(exception)
      end
    end
  end

  describe "#close" do
    let(:exception) { RuntimeError.new }
    let(:callback) { stub }

    it "closes the connection" do
      connection.should_receive(:close).at_least(1)
      socket.close
    end

    it "marks the socket as dead" do
      socket.close
      socket.should be_dead
    end
  end

  describe "#dead?" do
    context "when socket has been killed" do
      before do
        socket.close
      end

      it "should be dead" do
        socket.should be_dead
      end
    end

    context "when connection is closed" do
      before do
        socket.connection.close
      end

      it "should be dead" do
        socket.should be_dead
      end
    end
  end

end
