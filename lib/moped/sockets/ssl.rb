require 'openssl'
module Moped
  module Sockets

    # This is a wrapper around a tcp socket.
    class SSL < TCP
      attr_reader :ssl

      # Initialize the new TCPSocket with SSL.
      #
      # @example Initialize the socket.
      #   SSL.new("127.0.0.1", 27017, OpenSSL::SSL::SSLContext.new)
      #
      # @param [ String ] host The host.
      # @param [ Integer ] port The port.
      # @param [ OpenSSL::SSL::SSLContext ] context The SSLContext.
      #
      # @since 1.2.0
      def initialize(host, port, context, *args)
        super host, port, *args

        @ssl = OpenSSL::SSL::SSLSocket.new(self, context)
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

      class << self

        # Connect to the tcp server.
        #
        # @example Connect to the server.
        #   SSL.connect("127.0.0.1", 27017, 30, true)
        #
        # @param [ String ] host The host to connect to.
        # @param [ Integer ] post The server port.
        # @param [ Integer ] timeout The connection timeout.
        # @param [ Boolean ] ssl_options If boolean then assume default options.
        # @param [ Hash ] ssl_options Supply custom SSL options to SSLContext.
        #
        # @option ssl_options [ Boolean ] :verify_peer Flag for SSLContext.verify_mode
        # @option ssl_options [ String ] :ca_path
        # @option ssl_options [ String ] :ca_file
        # @option ssl_options [ String ] :client_cert
        # @option ssl_options [ String ] :client_key
        #
        # @return [ TCPSocket ] The socket.
        #
        # @since 1.0.0
        def connect(host, port, timeout, ssl_options = true)
          Timeout::timeout(timeout) do

            context = OpenSSL::SSL::SSLContext.new

            if ssl_options.is_a?(Hash)

              if !!ssl_options[:verify_peer]
                context.verify_mode = OpenSSL::SSL::VERIFY_PEER

                if ssl_options[:ca_path]
                  context.ca_path = ssl_options[:ca_path]
                elsif ssl_options[:ca_file]
                  context.ca_file = ssl_options[:ca_file]
                else
                  store = OpenSSL::X509::Store.new
                  store.set_default_paths
                  context.cert_store = store
                end
              else
                context.verify_mode = OpenSSL::SSL::VERIFY_NONE
              end

              if ssl_options.has_key?(:client_cert) && ssl_options.has_key?(:client_key)
                context.cert = OpenSSL::X509::Certificate.new(File.read(ssl_options[:client_cert]))
                context.key = OpenSSL::PKey::RSA.new(File.read(ssl_options[:client_key]))
              end
            else
              context.verify_mode = OpenSSL::SSL::VERIFY_NONE
            end

            sock = new(host, port, context)
            sock.set_encoding('binary')
            sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
            sock
          end
        end
      end
    end
  end
end
