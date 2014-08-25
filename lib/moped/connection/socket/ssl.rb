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
        def initialize(host, port, options)
          @host, @port = host, port
          handle_socket_errors do
            @socket = TCPSocket.new(host, port)

            context = OpenSSL::SSL::SSLContext.new
            if options.is_a?(Hash)
              if options['ca_path']
                context.ca_path = options['ca_path']
              elsif options['ca_file']
                context.ca_file = options['ca_file']
              else
                store = OpenSSL::X509::Store.new
                store.set_default_paths
                context.cert_store = store
              end

              if options.has_key?('client_cert') && options.has_key?('client_key')
                context.cert = OpenSSL::X509::Certificate.new(File.read(options['client_cert']))
                context.key = OpenSSL::PKey::RSA.new(File.read(options['client_key']))
              end
            end

            super(socket, context)
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
