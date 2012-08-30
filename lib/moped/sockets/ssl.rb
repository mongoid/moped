require 'openssl'
module Moped
  module Sockets

    # This is a wrapper around a tcp socket.
    class SSL < TCP
      attr_reader :ssl

      # Initialize the new TCPSocket with SSL.
      #
      # @example Initialize the socket.
      #   SSL.new("127.0.0.1", 27017)
      #
      # @param [ String ] host The host.
      # @param [ Integer ] port The port.
      #
      # @since 1.2.0
      def initialize(host, port, *args)
        super
        @ssl = OpenSSL::SSL::SSLSocket.new(self)
        @ssl.sync_close = true
        handle_socket_errors { @ssl.connect }
      end

      # Read from the TCP socket.
      #
      # @param [ Integer ] length The length to read.
      #
      # @return [ Object ] The data.
      #
      # @since 1.2.0
      def read(length)
        handle_socket_errors { @ssl.read(length) }
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
        handle_socket_errors { @ssl.write(*args) }
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
      rescue OpenSSL::SSL::SSLError => e
        raise Errors::ConnectionFailure, "SSL Error '#{e.to_s}' for connection to Mongo on #{host}:#{port}"
      end
      
    end
  end
end
