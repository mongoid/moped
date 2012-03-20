module Moped

  # @api private
  #
  # The internal class for storing information about a server.
  class Server

    # @return [String] the original host:port address provided
    attr_reader :address

    # @return [String] the resolved host:port address
    attr_reader :resolved_address

    # @return [String] the resolved ip address
    attr_reader :ip_address

    # @return [Integer] the resolved port
    attr_reader :port

    attr_writer :primary
    attr_writer :secondary

    def initialize(address)
      @address = address

      host, port = address.split(":")
      port = port ? port.to_i : 27017

      ip_address = ::Socket.getaddrinfo(host, nil, ::Socket::AF_INET, ::Socket::SOCK_STREAM).first[3]

      @primary = @secondary = false
      @ip_address = ip_address
      @port = port
      @resolved_address = "#{ip_address}:#{port}"
    end

    def primary?
      !!@primary
    end

    def secondary?
      !!@secondary
    end

    def merge(other)
      @primary = other.primary?
      @secondary = other.secondary?

      other.close
    end

    def close
      if @socket
        @socket.close
        @socket = nil
      end
    end

    def socket
      @socket ||= Socket.new(ip_address, port)
    end

    def ==(other)
      self.class === other && hash == other.hash
    end
    alias eql? ==

    def hash
      [ip_address, port].hash
    end

  end
end
