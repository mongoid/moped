require 'openssl'

module Moped
  module Sockets

    # This is a wrapper around a tcp socket.
    class SSL < OpenSSL::SSL::SSLSocket
      include Connectable

      attr_reader :socket

      # Initialize the new TCPSocket with SSL.
      #
      # @example Initialize the socket.
      #   SSL.new("127.0.0.1", 27017)
      #
      # @param [ String ] host The host.
      # @param [ Integer ] port The port.
      #
      # @since 1.2.0
      def initialize(host, port)
        @host, @port = host, port
        handle_socket_errors do
          @socket = TCPSocket.new(host, port)
          super(socket)
        end
      end

      # Set the encoding of the underlying socket.
      #
      # @param [ String ] string The encoding.
      #
      # @since 1.3.0
      def set_encoding(string)
        socket.set_encoding(string)
      end

      # Set a socket option on the underlying socket.
      #
      # @param [ Integer ] level The option level.
      # @param [ Integer ] option The option.
      # @param [ Object ] value The option value.
      #
      # @since 1.3.0
      def setsockopt(level, option, value)
        socket.setsockopt(level, option, value)
      end
    end
  end
end
