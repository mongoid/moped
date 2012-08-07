module Moped
  module Sockets

    # This is a wrapper around a tcp socket.
    class TCP < ::TCPSocket
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
