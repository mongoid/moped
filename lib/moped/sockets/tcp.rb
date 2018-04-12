module Moped
  module Sockets

    # This is a wrapper around a tcp socket.
    class TCP < ::TCPSocket
      include Connectable

      # Initialize the new TCPSocket.
      #
      # @example Initialize the socket.
      #   TCPSocket.new("127.0.0.1", 27017)
      #
      # @param [ String ] host The host.
      # @param [ Integer ] port The port.
      #
      # @since 1.2.0
      def initialize(host, port)
        @host, @port = host, port
        handle_socket_errors { super }
      end
    end
  end
end
