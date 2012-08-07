module Support

  # This is a helper class for testing replica sets. It works by starting up a
  # TCP server socket for each desired node. It then proxies all traffic
  # between a real mongo instance and the client app, with the exception of
  # ismaster commands, which it returns simulated responses for.
  class ReplicaSetSimulator

    module Helpers
      def self.included(context)
        context.let :seeds do
          @replica_set.nodes.map(&:address)
        end
      end
    end

    def self.configure(config)
      config.before :all, replica_set: true do |example|
        @replica_set = ReplicaSetSimulator.new
        @replica_set.start

        @primary, @secondaries = @replica_set.initiate
      end

      config.after :each, replica_set: true do
        @replica_set.nodes.each(&:restart)
      end

      config.after :all, replica_set: true do
        @replica_set.stop
      end

      config.include Helpers, replica_set: true
    end

    attr_reader :nodes
    attr_reader :manager

    def initialize(nodes = 3)
      start_port = 31000
      @nodes = nodes.times.map do |i|
        Node.new(self, start_port + i)
      end

      @manager = ConnectionManager.new(@nodes)
      @mongo = TCPSocket.new "127.0.0.1", 27017
    end

    # Start the mock replica set.
    def start
      @nodes.each(&:start)
      @worker = Thread.start do
        Thread.abort_on_exception = true
        catch(:shutdown) do
          loop do
            Moped.logger.debug "replica_set: waiting for next client"
            server, client = @manager.next_client

            if server
              Moped.logger.debug "replica_set: proxying incoming request to mongo"
              server.proxy(client, @mongo)
            else
              Moped.logger.debug "replica_set: no requests; passing"
              Thread.pass
            end
          end
        end
      end
    end

    # Pick a node to be master, and mark the rest as secondary
    def initiate
      primary, *secondaries = @nodes.shuffle

      primary.promote
      secondaries.each(&:demote)

      return primary, secondaries
    end

    # Shut down the mock replica set.
    def stop
      @manager.shutdown
      @nodes.each(&:stop)
    end

    class Node

      attr_reader :port
      attr_reader :host

      def initialize(set, port)
        @set = set
        @primary = false
        @secondary = false

        @host = Socket.gethostname
        @port = port
        @hiccup_on_next_message = nil
      end

      def ==(other)
        @host == other.host && @port == other.port
      end

      def address
        "#{@host}:#{@port}"
      end

      def primary?
        @primary
      end

      def secondary?
        @secondary
      end

      def status
        {
          "ismaster" => @primary,
          "secondary" => @secondary,
          "hosts" => @set.nodes.map(&:address),
          "me" => address,
          "maxBsonObjectSize" => 16777216,
          "ok" => 1.0
        }
      end

      def status_reply
        reply = Moped::Protocol::Reply.new
        reply.count = 1
        reply.documents = [status]
        reply
      end

      OP_QUERY = 2004
      OP_GETMORE = 2005

      # Stop and start the node.
      def restart
        stop
        start
      end

      # Start the node.
      def start
        @server = TCPServer.new @port
      end

      # Stop the node.
      def stop
        if @server
          hiccup

          # We need the shutdown on travis, but my iMac complains about this.
          @server.shutdown rescue nil
          @server.close
          @server = nil
        end
      end
      alias close stop

      def accept
        to_io.accept
      end

      def closed?
        !@server || @server.closed?
      end

      def to_io
        @server
      end

      # Mark this node as secondary.
      def demote
        @primary = false
        @secondary = true

        hiccup
      end

      def hiccup
        @set.manager.close_clients_for(self)
      end

      # Mark this node as primary. This also closes any open connections.
      def promote
        @primary = true
        @secondary = false

        hiccup
      end

      def hiccup_on_next_message!
        @hiccup_on_next_message = true
      end

      # Proxies a single message from client to the mongo connection.
      def proxy(client, mongo)
        if @hiccup_on_next_message
          @hiccup_on_next_message = false
          return hiccup
        end

        incoming_message = client.read(16)
        length, op_code = incoming_message.unpack("l<x8l<")
        incoming_message << client.read(length - 16)

        if op_code == OP_QUERY && ismaster_command?(incoming_message)
          # Intercept the ismaster command and send our own reply.
          client.write status_reply
        else
          # This is a normal command, so proxy it to the real mongo instance.
          mongo.write incoming_message

          if op_code == OP_QUERY || op_code == OP_GETMORE
            outgoing_message = mongo.read(4)
            length, = outgoing_message.unpack('l<')
            outgoing_message << mongo.read(length - 4)

            client.write outgoing_message
          end
        end
      rescue
      end

      private

      # Checks a message to see if it's an `ismaster` query.
      def ismaster_command?(incoming_message)
        data = StringIO.new(incoming_message)
        data.read(20) # header and flags
        data.gets("\x00") # collection name
        data.read(8) # skip/limit

        selector = Moped::BSON::Document.deserialize(data)
        selector == { "ismaster" => 1 }
      end
    end

    class ConnectionManager

      def initialize(servers)
        @timeout = 0.1
        @servers = servers
        @clients = []
        @shutdown = nil
      end

      def shutdown
        @clients.each do |client|
          begin
            client.shutdown unless RUBY_PLATFORM =~ /java/
            client.close
          rescue
          end
        end
        @shutdown = true
      end

      def next_client
        throw :shutdown if @shutdown

        begin
          servers = @servers.reject(&:closed?)
          clients =  @clients.reject(&:closed?)
          Moped.logger.debug "replica_set: selecting on connections"
          readable, _, errors = Kernel.select(servers + clients, nil, clients, @timeout)
        rescue IOError, Errno::EBADF, TypeError
          # Looks like we hit a bad file descriptor or closed connection.
          Moped.logger.debug "replica_set: io error, retrying"
          retry
        end

        return unless readable || errors

        errors.each do |client|
          begin
            client.shutdown unless RUBY_PLATFORM =~ /java/
            client.close
          rescue
          end
          @clients.delete client
        end

        clients, servers = readable.partition { |s| s.class == TCPSocket }

        servers.each do |server|
          Moped.logger.debug "replica_set: accepting new client for #{server.port}"
          @clients << server.accept
        end

        Moped.logger.debug "replica_set: closing dead clients"
        closed, open = clients.partition do |client|
          begin
            client.eof?
          rescue IOError
            true
          end
        end
        closed.each { |client| @clients.delete client }

        if client = open.shift
          Moped.logger.debug "replica_set: finding server for client"
          server = lookup_server(client)

          Moped.logger.debug "replica_set: sending client #{client.inspect} to #{server.port}"
          return server, client
        else
          nil
        end
      end

      def close_clients_for(server)
        Moped.logger.debug "replica_set: closing open clients on #{server.port}"

        @clients.reject! do |client|
          port = client.addr(false)[1]

          if port == server.port
            begin
              # We need the shutdown for the travis ubuntu boxes, but it causes
              # problems with jruby.
              client.shutdown unless RUBY_PLATFORM =~ /java/
              client.close
            rescue
            end
            true
          else
            false
          end
        end
      end

      def lookup_server(client)
        port = client.addr(false)[1]

        @servers.find do |server|
          server.to_io && server.to_io.addr[1] == port
        end
      end
    end
  end
end
