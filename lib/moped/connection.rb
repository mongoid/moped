# encoding: utf-8
require "moped/connection/manager"
require "moped/connection/sockets"
require "socket"

module Moped

  # This class contains behaviour of database socket connections.
  #
  # @since 2.0.0
  class Connection
    include Authenticatable

    # The default connection timeout, in seconds.
    #
    # @since 2.0.0
    TIMEOUT = 5

    # @!attribute host
    #   @return [ String ] The ip address of the host.
    # @!attribute options
    #   @return [ Hash ] The connection options.
    # @!attribute port
    #   @return [ String ] The port the connection connects on.
    # @!attribute timeout
    #   @return [ Integer ] The timeout in seconds.
    attr_reader :host, :options, :port, :timeout

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
      credentials.clear
      @sock = if !!options[:ssl]
        Socket::SSL.connect(host, port, timeout)
      else
        Socket::TCP.connect(host, port, timeout)
      end
      set_tcp_keepalive
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
    # @param [ Hash ] options Options for the connection.
    #
    # @option options [ Boolean ] :ssl Connect using SSL
    # @since 1.0.0
    def initialize(host, port, timeout, options = {})
      @host = host
      @port = port
      @timeout = timeout
      @options = options
      @sock = nil
      @request_id = 0
      configure_tcp_keepalive(@options[:keepalive])
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
        data = read_data(socket, 36)
        response = data.unpack('l<5q<l<2')
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
          sock_read = read_data(socket, reply.length - 36)
          buffer = StringIO.new(sock_read)
          reply.documents = reply.count.times.map do
            ::BSON::Document.from_bson(buffer)
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


    # Configure the TCP Keeplive if it is a FixNum. If it is hash 
    # validate he settings are FixNums.
    #
    # @example With a FixNum
    #   configure_tcp_keepalive(60)
    #
    # @example With a Hash
    #   configure_tcp_keepalive({:time => 30, :intvl => 20, :probes => 2})    
    #
    # @param [ FixNum ] | [ Hash ] Supply a Fixnum to allow the specific settings to be 
    #                   configured for you. Supply a Hash with the :time, :intvl, and :probes
    #                   keys to set specific values
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def configure_tcp_keepalive(keepalive)
      case keepalive
      when Hash
        [:time, :intvl, :probes].each do |key|
          unless  keepalive[key].is_a?(Fixnum)
            raise "Expected the #{key.inspect} key in :tcp_keepalive to be a Fixnum"
          end
        end
      when Fixnum
        if keepalive >= 60
          keepalive = {:time => keepalive - 20, :intvl => 10, :probes => 2}

        elsif keepalive >= 30
          keepalive = {:time => keepalive - 10, :intvl => 5, :probes => 2}

        elsif keepalive >= 5
          keepalive = {:time => keepalive - 2, :intvl => 2, :probes => 1}
        end
      end  
      @keepalive = keepalive    
    end

    # Read data from the socket until we get back the number of bytes that we
    # are expecting.
    #
    # @api private
    #
    # @example Read the number of bytes.
    #   connection.read_data(socket, 36)
    #
    # @param [ TCPSocket ] socket The socket to read from.
    # @param [ Integer ] length The number of bytes to read.
    #
    # @return [ String ] The read data.
    #
    # @since 1.2.9
    def read_data(socket, length)
      data = socket.read(length)
      unless data
        raise Errors::ConnectionFailure.new(
          "Attempted to read #{length} bytes from the socket but nothing was returned."
        )
      end
      if data.length < length
        data << read_data(socket, length - data.length)
      end
      data
    end

    if [:SOL_SOCKET, :SO_KEEPALIVE, :SOL_TCP, :TCP_KEEPIDLE, :TCP_KEEPINTVL, :TCP_KEEPCNT].all?{|c| ::Socket.const_defined? c}
      # Enable the tcp_keepalive
      #
      # @api private
      #
      # @example
      #   enable_tcp_keepalive
      #
      # @return [ nil ] nil.
      #
      # @since 2.0.5
      def enable_tcp_keepalive
        return unless @keepalive.is_a?(Hash)
        @sock.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE,  true)
        @sock.setsockopt(::Socket::SOL_TCP,    ::Socket::TCP_KEEPIDLE,  @keepalive[:time])
        @sock.setsockopt(::Socket::SOL_TCP,    ::Socket::TCP_KEEPINTVL, @keepalive[:intvl])
        @sock.setsockopt(::Socket::SOL_TCP,    ::Socket::TCP_KEEPCNT,   @keepalive[:probes])
        Loggable.debug("  MOPED:", "Configured TCP keepalive for connection with #{@keepalive.inspect}", "n/a") 
      end
    else
      # Skeleton method that doesn't enable the tcp_keepalive.
      # It simply logs a message saying the feature isn't supported.
      #
      # @api private
      #
      # @example With a Hash
      #   enable_tcp_keepalive
      #
      # @return [ nil ] nil.
      #
      # @since 2.0.5      
      def enable_tcp_keepalive
        Loggable.debug("  MOPED:", "Did not configure TCP keepalive for connection as it is not supported on this platform.", "n/a") 
      end
    end    

    # Yields a connected socket to the calling back. It will attempt to reconnect
    # the socket if it is not connected.
    #
    # @api private
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
      if @sock.nil? || !@sock.alive?
        connect
        apply_credentials(@original_credentials || {})
      end
      yield @sock
    end
  end
end
