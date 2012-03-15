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
    connection.close if connection && !connection.closed?
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

  describe "#connect" do
    context "when node is not running" do
      let(:bogus_port) do
        server = TCPServer.new("127.0.0.1", 0)
        server.addr[1].tap do
          server.close
        end
      end

      let(:socket) do
        described_class.new "127.0.0.1", bogus_port
      end

      it "returns false" do
        socket.connect.should be_false
      end
    end

    context "when connection times out" do
      if RUBY_PLATFORM == "java"
        let(:timeout_server) do
          java.net.ServerSocket.new(0, 1)
        end

        let(:timeout_port) do
          timeout_server.getLocalPort
        end
      else
        let(:timeout_server) do
          TCPServer.new("127.0.0.1", 0).tap do |server|
            server.listen(1)
          end
        end

        let(:timeout_port) do
          timeout_server.addr[1]
        end
      end

      let(:timeout_socket) do
        described_class.new "127.0.0.1", timeout_port
      end

      before do
        sockaddr = Socket.pack_sockaddr_in(timeout_port, '127.0.0.1')

        5.times do # flood the server socket
          ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM, 0).connect_nonblock(sockaddr) rescue nil
        end
      end

      after do
        timeout_server.close unless timeout_server.closed?
      end

      it "returns false" do
        timeout_socket.connect.should be_false
      end
    end
  end

  describe "#alive?" do
    context "when not connected" do
      let(:socket) do
        described_class.new("127.0.0.1", 99999).tap do |socket|
          socket.stub(:connect)
        end
      end

      it "should be false" do
        socket.should_not be_alive
      end
    end

    context "when connected but server goes away" do
      before do
        remote = server.accept
        remote.shutdown
        # Give the socket time to be notified
        sleep 0.1
      end

      it "should be false" do
        socket.should_not be_alive
      end
    end

    context "when connected but server goes away" do
      before do
        server.close
        # Give the socket time to be notified
        sleep 0.1
      end

      it "should be false" do
        socket.should_not be_alive
      end
    end

    context "when connect is explicitly closed" do
      before do
        socket.close
      end

      it "should be false" do
        socket.should_not be_alive
      end
    end

    context "when connected and server is open" do
      it "should be true" do
        socket.should be_alive
      end
    end
  end

  describe "#execute" do
    let(:query) { Moped::Protocol::Query.new(:moped, :test, {}) }

    context "when competing threads attempt to query" do
      let(:messages) do
        10.times.map do |i|
          Moped::Protocol::Insert.new(:moped, :test, {}).tap do |query|
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

        threads.each(&:join)

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
      Moped::Protocol::Reply.allocate.tap do |reply|
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

  describe "#close" do
    let(:exception) { RuntimeError.new }
    let(:callback) { stub }

    it "closes the connection" do
      connection.should_receive(:close).at_least(1)
      socket.close
    end

    it "marks the socket as dead" do
      socket.close
      socket.should_not be_alive
    end
  end

  describe "#login" do

    let(:connection) do
      Support::MockConnection.new
    end

    before do
      socket.stub(connection: connection)
    end

    context "when authentication is successful" do
      before do
        # getnonce
        connection.pending_replies << Hash["nonce" => "123", "ok" => 1]
        # authenticate
        connection.pending_replies << Hash["ok" => 1]
      end

      it "returns true" do
        socket.login("admin", "username", "password").should be_true
      end

      it "adds the credentials to the auth cache" do
        socket.login(:admin, "username", "password")
        socket.auth.should eq("admin" => ["username", "password"])
      end
    end

    context "when a nonce fails to generate" do
      before do
        # getnonce
        connection.pending_replies << Hash["ok" => 0]
      end

      it "raises an operation failure" do
        lambda do
          socket.login(:admin, "username", "password")
        end.should raise_exception(Moped::Errors::OperationFailure)
      end

      it "does not add the credentials to the auth cache" do
        socket.login(:admin, "username", "password") rescue nil
        socket.auth.should be_empty
      end
    end

    context "when authentication fails" do
      before do
        # getnonce
        connection.pending_replies << Hash["nonce" => "123", "ok" => 1]
        # authenticate
        connection.pending_replies << Hash["ok" => 0]
      end

      it "raises an operation failure" do
        lambda do
          socket.login(:admin, "username", "password")
        end.should raise_exception(Moped::Errors::OperationFailure)
      end

      it "does not add the credentials to the auth cache" do
        socket.login(:admin, "username", "password") rescue nil
        socket.auth.should be_empty
      end
    end

  end

  describe "#logout" do

    let(:connection) do
      Support::MockConnection.new
    end

    before do
      socket.stub(connection: connection)
      socket.auth["admin"] = ["username", "password"]
    end

    context "when logout is successful" do
      before do
        connection.pending_replies << Hash["ok" => 1]
      end

      it "removes the stored credentials" do
        socket.logout :admin
        socket.auth.should be_empty
      end
    end

    context "when logout is unsuccessful" do
      before do
        connection.pending_replies << Hash["ok" => 0]
      end

      it "does not remove the stored credentials" do
        socket.logout :admin rescue nil
        socket.auth.should_not be_empty
      end

      it "raises an operation failure" do
        lambda do
          socket.logout :admin
        end.should raise_exception(Moped::Errors::OperationFailure)
      end
    end

  end

  describe "#apply_auth" do
    context "when the socket is unauthenticated" do
      it "logs in with each credential provided" do
        socket.should_receive(:login).with("admin", "username", "password")
        socket.should_receive(:login).with("test", "username", "password")

        socket.apply_auth(
          "admin" => ["username", "password"],
          "test" => ["username", "password"]
        )
      end
    end

    context "when the socket is authenticated" do
      before do
        socket.auth["admin"] = ["username", "password"]
      end

      context "and a credential is unchanged" do
        it "does nothing" do
          socket.should_not_receive(:login)
          socket.apply_auth("admin" => ["username", "password"])
        end
      end

      context "and a credential changes" do
        it "logs in with the new credentials" do
          socket.should_receive(:login).with("admin", "newuser", "password")
          socket.apply_auth("admin" => ["newuser", "password"])
        end
      end

      context "and a credential is removed" do
        it "logs out from the database" do
          socket.should_receive(:logout).with("admin")
          socket.apply_auth({})
        end
      end

      context "and a credential is added" do
        it "logs in with the added credentials" do
          socket.should_receive(:login).with("test", "username", "password")
          socket.apply_auth(
            "admin" => ["username", "password"],
            "test" => ["username", "password"]
          )
        end
      end
    end
  end

  describe "instrument" do

    context "when a logger is configured in debug mode" do
      before do
        Moped.stub(logger: mock(Logger, debug?: true))
      end

      it "logs the operations" do
        socket.should_receive(:log_operations).once
        socket.instrument([]) {}
      end
    end

    context "when a logger is configured but not in debug level" do
      before do
        Moped.stub(logger: mock(Logger, debug?: false))
      end

      it "does not log the operations" do
        socket.should_receive(:log_operations).never
        socket.instrument([]) {}
      end
    end

    context "when no logger is configured" do
      before do
        Moped.stub(logger: nil)
      end

      it "does not log the operations" do
        socket.should_receive(:log_operations).never
        socket.instrument([]) {}
      end
    end

    context "when an error occurs" do
      before do
        Moped.stub(logger: mock(Logger, debug?: true))
      end

      it "does not log the operations" do
        socket.should_receive(:log_operations).never

        lambda do
          socket.instrument([]) { raise "inner error" }
        end.should raise_exception("inner error")
      end
    end

  end

end
