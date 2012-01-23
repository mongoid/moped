module Moped
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

      addrinfo = Addrinfo.tcp(*address.split(":"))

      @ip_address = addrinfo.ip_address
      @port = addrinfo.ip_port
      @resolved_address = addrinfo.inspect_sockaddr
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
