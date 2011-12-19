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

  before do
    described_class.any_instance.stub(:start_read_loop)
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
          Crutches::Protocol::Query.new(:crutches, :test, {}).tap do |query|
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

  describe "#simple_query" do
    it "returns the document" do
      socket.stub(:execute) do |query, callback|
        callback.call(nil, nil, nil, a: 1)
      end

      socket.simple_query("a").should eq(a: 1)
    end

    context "when execute fails" do
      it "raises the exception" do
        exception = RuntimeError.new

        socket.stub(:execute) do |query, callback|
          callback.call(exception)
        end

        lambda { socket.simple_query("a") }.
          should raise_exception(exception)
      end
    end
  end

  describe "#receive" do
    context "when reply's op code is not 1" do
      let(:reply) do
        Crutches::Protocol::Reply.allocate.tap do |reply|
          reply.length = 123
          reply.request_id = 123
          reply.response_to = 123
          reply.op_code = 123
          reply.documents = []
        end.serialize
      end

      it "raises an exception" do
        exception = RuntimeError.new
        connection = StringIO.new(reply)

        lambda { socket.receive(connection) }.should raise_exception("op-code != 1")
      end
    end

    context "when no callback is registered" do
      let(:reply) do
        Crutches::Protocol::Reply.allocate.tap do |reply|
          reply.length = 123
          reply.request_id = 123
          reply.response_to = 123
          reply.op_code = 1
          reply.documents = []
        end.serialize
      end

      it "does not raise an exception" do
        exception = RuntimeError.new
        connection = StringIO.new(reply)
        lambda { socket.receive(connection) }.should_not raise_exception
      end
    end

    context "when a callback is registered" do
      let(:callback) { stub }
      let(:connection) { StringIO.new(reply) }
      let(:request_id) { 1 }

      before do
        socket.callbacks[request_id] = callback
      end

      context "and no documents are returned" do
        let(:reply) do
          Crutches::Protocol::Reply.allocate.tap do |reply|
            reply.length = 123
            reply.request_id = 123
            reply.response_to = request_id
            reply.op_code = 1
            reply.documents = []
          end.serialize
        end

        it "calls the callback with the expected arguments" do
          callback.should_receive(:[]).once.with do |err, reply, index, doc|
            doc.should be_nil
            index.should eq -1
            doc.should be_nil
          end

          socket.receive connection
        end

        it "removes the callback" do
          callback.stub(:[])
          socket.receive connection
          socket.callbacks.should_not have_key(request_id)
        end
      end

      context "and multiple documents are returned" do
        let(:documents) do
          [ { "a" => 1 }, { "b" => 2 }, { "c" => 3} ]
        end

        let(:reply) do
          Crutches::Protocol::Reply.allocate.tap do |reply|
            reply.length = 123
            reply.request_id = 123
            reply.response_to = request_id
            reply.op_code = 1
            reply.count = 3
            reply.documents = documents
          end.serialize
        end

        it "calls the callback once for each document" do
          callback.should_receive(:[]).with(nil, anything, 0, documents[0])
          callback.should_receive(:[]).with(nil, anything, 1, documents[1])
          callback.should_receive(:[]).with(nil, anything, 2, documents[2])

          socket.receive connection
        end

        it "removes the callback" do
          callback.stub(:[])
          socket.receive connection
          socket.callbacks.should_not have_key(request_id)
        end
      end
    end
  end

  describe "#read_loop" do
    it "calls receive with the connection in a loop" do
      socket.should_receive(:loop) do |*args, &block|
        socket.should_receive(:receive).with(connection)
        block.call
      end

      socket.read_loop
    end

    context "when receive raises an error" do
      let(:exception) { RuntimeError.new }

      it "kills the socket" do
        socket.stub(:receive).and_raise(exception)
        socket.should_receive(:kill).with(exception)
        socket.read_loop
      end
    end
  end

  describe "#close" do
    it "kills the socket" do
      socket.should_receive(:kill)
      socket.close
    end
  end

  describe "#kill" do
    let(:exception) { RuntimeError.new }
    let(:callback) { stub }

    it "closes the connection" do
      connection.should_receive(:close).at_least(1)
      socket.kill exception
    end

    it "notifies all registered callbacks of the exception" do
      socket.callbacks[1] = callback

      callback.should_receive(:[]).with(exception)
      socket.kill exception
    end

    it "marks the socket as dead" do
      socket.kill exception
      socket.should be_dead
    end
  end

  describe "#dead?" do
    context "when socket has been killed" do
      before do
        socket.kill RuntimeError.new
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

    context "when the server goes away" do
      it "should be dead" do
        socket
        t = Thread.new { socket.read_loop }
        server.close
        sleep 0.5
        socket.should be_dead
      end
    end
  end

end
