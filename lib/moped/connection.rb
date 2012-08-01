require "timeout"

module Moped

  # This class contains behaviour of database socket connections.
  #
  # @api private
  class Connection
    # Is the connection alive?
    #
    # @example Is the connection alive?
    #   connection.alive?
    #
    # @return [ true, false ] If the connection is alive.
    #
    # @since 1.0.0
    def alive?
      connected? ? @sock.alive? : false
    end

    # Connect to the server defined by @host, @port without timeout @timeout.
    #
    # @example Open the connection
    #   connection.connect
    #
    # @return [ TCPSocket ] The socket.
    #
    # @since 1.0.0
    def connect
      create_connection
    end

    # Is the connection connected?
    #
    # @example Is the connection connected?
    #   connection.connected?
    #
    # @return [ true, false ] If the connection is connected.
    #
    # @since 1.0.0
    def connected?
      !!@sock
    end

    # Disconnect from the server.
    #
    # @example Disconnect from the server.
    #   connection.disconnect
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def disconnect
      @sock.close
    rescue
    ensure
      @sock = nil
    end

    # Initialize the connection.
    #
    # @example Initialize the connection.
    #   Connection.new("localhost", 27017, 5)
    #
    # @param [ String ] host The host to connect to.
    # @param [ Integer ] post The server port.
    # @param [ Integer ] timeout The connection timeout.
    # @since 1.0.0
    def initialize(host, port, timeout)
      @sock = nil
      @request_id = 0
      @host = host
      @port = port
      @timeout = timeout
    end

    # Read from the connection.
    #
    # @example Read from the connection.
    #   connection.read
    #
    # @return [ Hash ] The returned document.
    #
    # @since 1.0.0
    def read
      with_connection do |socket|
        reply = Protocol::Reply.allocate
        response = socket.read(36).unpack('l<5q<l<2')
        reply.length,
            reply.request_id,
            reply.response_to,
            reply.op_code,
            reply.flags,
            reply.cursor_id,
            reply.offset,
            reply.count = response

        if reply.count == 0
          reply.documents = []
        else
          sock_read = socket.read(reply.length - 36)

          buffer = StringIO.new(sock_read)

          reply.documents = reply.count.times.map do
            BSON::Document.deserialize(buffer)
          end
        end
        reply
      end
    end

    # Get the replies to the database operation.
    #
    # @example Get the replies.
    #   connection.receive_replies(operations)
    #
    # @param [ Array<Message> ] operations The query or get more ops.
    #
    # @return [ Array<Hash> ] The returned deserialized documents.
    #
    # @since 1.0.0
    def receive_replies(operations)
      operations.map do |operation|
        operation.receive_replies(self)
      end
    end

    # Write to the connection.
    #
    # @example Write to the connection.
    #   connection.write(data)
    #
    # @param [ Array<Message> ] operations The database operations.
    #
    # @return [ Integer ] The number of bytes written.
    #
    # @since 1.0.0
    def write(operations)
      buf = ""
      operations.each do |operation|
        operation.request_id = (@request_id += 1)
        operation.serialize(buf)
      end
      with_connection do |socket|
        socket.write(buf)
      end
    end

    private

    def create_connection
      @sock = TCPSocket.connect @host, @port, @timeout
    end

    # Yields a connected socket to the calling back. It will attempt to reconnect
    # the socket if it is not connected.
    #
    # @example Write to the connection.
    #   with_connection do |socket|
    #     socket.write(buf)
    #   end
    #
    # @return The yielded block
    #
    # @since 1.3.0
    def with_connection
      create_connection if @sock.nil? || !@sock.alive?
      yield @sock
    end

    # This is a wrapper around a tcp socket.
    class TCPSocket < ::TCPSocket
      attr_reader :host, :port

      # Is the socket connection alive?
      #
      # @example Is the socket alive?
      #   socket.alive?
      #
      # @return [ true, false ] If the socket is alive.
      #
      # @since 1.0.0
      def alive?
        if Kernel::select([ self ], nil, nil, 0)
          !eof? rescue false
        else
          true
        end
      end

      # Initialize the new TCPSocket.
      #
      # @example Initialize the socket.
      #   TCPSocket.new("127.0.0.1", 27017)
      #
      # @param [ String ] host The host.
      # @param [ Integer ] port The port.
      #
      # @since 1.2.0
      def initialize(host, port, *args)
        @host, @port = host, port
        handle_socket_errors { super }
      end

      # Read from the TCP socket.
      #
      # @param [ Integer ] length The length to read.
      #
      # @return [ Object ] The data.
      #
      # @since 1.2.0
      def read(length)
        handle_socket_errors { super }
      end

      # Write to the socket.
      #
      # @example Write to the socket.
      #   socket.write(data)
      #
      # @param [ Object ] args The data to write.
      #
      # @return [ Integer ] The number of bytes written.
      #
      # @since 1.0.0
      def write(*args)
        raise Errors::ConnectionFailure, "Socket connection was closed by remote host" unless alive?
        handle_socket_errors { super }
      end

      private

      def handle_socket_errors
        yield
      rescue Timeout::Error
        raise Errors::ConnectionFailure, "Timed out connection to Mongo on #{host}:#{port}"
      rescue Errno::ECONNREFUSED
        raise Errors::ConnectionFailure, "Could not connect to Mongo on #{host}:#{port}"
      rescue Errno::ECONNRESET
        raise Errors::ConnectionFailure, "Connection reset to Mongo on #{host}:#{port}"
      end

      class << self

        # Connect to the tcp server.
        #
        # @example Connect to the server.
        #   TCPSocket.connect("127.0.0.1", 27017, 30)
        #
        # @param [ String ] host The host to connect to.
        # @param [ Integer ] post The server port.
        # @param [ Integer ] timeout The connection timeout.
        #
        # @return [ TCPSocket ] The socket.
        #
        # @since 1.0.0
        def connect(host, port, timeout)
          Timeout::timeout(timeout) do
            sock = new(host, port)
            sock.set_encoding('binary')
            sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
            sock
          end
        end
      end
    end
  end
end
