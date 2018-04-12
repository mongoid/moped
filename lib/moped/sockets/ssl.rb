require 'openssl'

module Moped
  module Sockets

    # This is a wrapper around a tcp socket.
    class SSL < OpenSSL::SSL::SSLSocket
      include Connectable

      attr_reader :socket

      attr_reader :options

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
        @context = create_context(options)
        @host, @port = host, port
        handle_socket_errors do
          @socket = TCPSocket.new(host, port)
          super(socket, context)
          self.sync_close = true
          connect
          verify_certificate!
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

    private

      def create_context(options)
        context = OpenSSL::SSL::SSLContext.new
        set_cert(context, options)
        set_key(context, options)
        set_cert_verification(context, options) unless options[:ssl_verify] == false
        context
      end

      def set_cert(context, options)
        if options[:ssl_cert]
          context.cert = OpenSSL::X509::Certificate.new(File.open(options[:ssl_cert]))
        elsif options[:ssl_cert_string]
          context.cert = OpenSSL::X509::Certificate.new(options[:ssl_cert_string])
        elsif options[:ssl_cert_object]
          context.cert = options[:ssl_cert_object]
        end
      end

      def set_key(context, options)
        passphrase = options[:ssl_key_pass_phrase]
        if options[:ssl_key]
          context.key = passphrase ? OpenSSL::PKey.read(File.open(options[:ssl_key]), passphrase) :
            OpenSSL::PKey.read(File.open(options[:ssl_key]))
        elsif options[:ssl_key_string]
          context.key = passphrase ? OpenSSL::PKey.read(options[:ssl_key_string], passphrase) :
            OpenSSL::PKey.read(options[:ssl_key_string])
        elsif options[:ssl_key_object]
          context.key = options[:ssl_key_object]
        end
      end

      def set_cert_verification(context, options)
        context.verify_mode = OpenSSL::SSL::VERIFY_PEER
        cert_store = OpenSSL::X509::Store.new
        if options[:ssl_ca_cert]
          cert_store.add_cert(OpenSSL::X509::Certificate.new(File.open(options[:ssl_ca_cert])))
        elsif options[:ssl_ca_cert_string]
          cert_store.add_cert(OpenSSL::X509::Certificate.new(options[:ssl_ca_cert_string]))
        elsif options[:ssl_ca_cert_object]
          raise TypeError("Option :ssl_ca_cert_object should be an array of OpenSSL::X509:Certificate objects") unless options[:ssl_ca_cert_object].is_a? Array
          options[:ssl_ca_cert_object].each {|cert| cert_store.add_cert(cert)}
        else
          cert_store.set_default_paths
        end
        context.cert_store = cert_store
      end

      def verify_certificate!
        if context.verify_mode == OpenSSL::SSL::VERIFY_PEER
          unless OpenSSL::SSL.verify_certificate_identity(self.peer_cert, self.hostname)
            raise Error::SocketError, 'SSL handshake failed due to a hostname mismatch.'
          end
        end
      end
    end
  end
end
