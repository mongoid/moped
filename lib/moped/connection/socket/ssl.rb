require "openssl"

module Moped
  class Connection
    module Socket

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
            self.sync_close = true
            connect
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
        # @param [ Array<Object> ] args The option arguments.
        #
        # @since 1.3.0
        def setsockopt(*args)
          socket.setsockopt(*args)
        end
      end
    end
  end
end
