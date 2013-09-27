# encoding: utf-8
module Moped

  # Encapsulates behaviour around addresses and resolving dns.
  #
  # @since 2.0.0
  class Address

    # @!attribute host
    #   @return [ String ] The host name.
    # @!attribute ip
    #   @return [ String ] The ip address.
    # @!attribute original
    #   @return [ String ] The original host name.
    # @!attribute port
    #   @return [ Integer ] The port.
    # @!attribute resolved
    #   @return [ String ] The full resolved address.
    attr_reader :host, :ip, :original, :port, :resolved

    # Instantiate the new address.
    #
    # @example Instantiate the address.
    #   Moped::Address.new("localhost:27017")
    #
    # @param [ String ] address The host:port pair as a string.
    #
    # @since 2.0.0
    def initialize(address)
      @original = address
      @host, port = address.split(":")
      @port = (port || 27017).to_i
    end

    # Resolve the address for the provided node. If the address cannot be
    # resolved the node will be flagged as down.
    #
    # @example Resolve the address.
    #   address.resolve(node)
    #
    # @param [ Node ] node The node to resolve for.
    #
    # @return [ String ] The resolved address.
    #
    # @since 2.0.0
    def resolve(node)
      begin
        @ip ||= Socket.getaddrinfo(host, nil, Socket::AF_INET, Socket::SOCK_STREAM).first[3]
        @resolved ||= "#{ip}:#{port}"
      rescue SocketError => e
        Loggable.warn("  MOPED:", "Could not resolve IP for: #{original}", "n/a")
        node.down! and false
      end
    end
  end
end
