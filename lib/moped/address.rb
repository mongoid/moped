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
    def initialize(address, timeout)
      @original = address

      if (parts = address.match(/\[(.+)\]:?(.+)?/))
        @host = parts[1]
        @port = (parts[2] || 27017).to_i
      else
        @host, port = address.split(":")
        @port = (port || 27017).to_i
      end

      @timeout = timeout
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
      return @resolved if @resolved
      start = Time.now
      retries = 0
      begin
        # This timeout should be very large since Timeout::timeout plays very badly with multithreaded code
        # TODO: Remove this Timeout entirely
        Timeout::timeout(@timeout * 10) do
          Resolv.each_address(host) do |ip|
            if ip =~ Resolv::IPv4::Regex || ip =~ Resolv::IPv6::Regex
              @ip ||= ip
              break
            end
          end
          raise Resolv::ResolvError unless @ip
        end
        @resolved = "#{ip}:#{port}"
      rescue Timeout::Error, Resolv::ResolvError, SocketError => e
        msg = ["  MOPED:", "Could not resolve IP for: #{original}, delta is #{Time.now - start}, error class is #{e.inspect}, retries is #{retries}. Node is #{node.inspect}", "n/a"]
        if retries == 0
          Loggable.info(*msg)
        else
          Loggable.warn(*msg)
        end
        if retries < 2
          retries += 1
          retry
        else
          node.down! and false
        end
      end
    end
  end
end
