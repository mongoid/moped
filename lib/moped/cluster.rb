module Moped

  # @api private
  #
  # The internal class managing connections to both a single node and replica
  # sets.
  #
  # @note Though the socket class itself *is* threadsafe, the cluster presently
  #   is not. This means that in the course of normal operations sessions can be
  #   shared across threads, but in failure modes (when a resync is required),
  #   things can possibly go wrong.
  class Cluster

    # @return [Array] the user supplied seeds
    attr_reader :seeds

    # @return [Boolean] whether this is a direct connection
    attr_reader :direct

    # @return [Array] all available nodes
    attr_reader :servers

    # @return [Array] seeds gathered from cluster discovery
    attr_reader :dynamic_seeds

    # @param [Array] seeds an array of host:port pairs
    # @param [Boolean] direct (false) whether to connect directly to the hosts
    # provided or to find additional available nodes.
    def initialize(seeds, direct = false)
      @seeds  = seeds
      @direct = direct

      @servers = []
      @dynamic_seeds = []
    end

    # @return [Array] available secondary nodes
    def secondaries
      servers.select(&:secondary?)
    end

    # @return [Array] available primary nodes
    def primaries
      servers.select(&:primary?)
    end

    # @return [Array] all known addresses from user supplied seeds, dynamically
    # discovered seeds, and active servers.
    def known_addresses
      [].tap do |addresses|
        addresses.concat seeds
        addresses.concat dynamic_seeds
        addresses.concat servers.map { |server| server.address }
      end.uniq
    end

    def remove(server)
      servers.delete(server)
    end

    def reconnect
      @servers = servers.map { |server| Server.new(server.address) }
    end

    def sync
      known = known_addresses.shuffle
      seen  = {}

      sync_seed = ->(seed) do
        server = Server.new seed

        unless seen[server.resolved_address]
          seen[server.resolved_address] = true

          hosts = sync_server(server)

          hosts.each do |host|
            sync_seed[host]
          end
        end
      end

      known.each do |seed|
        sync_seed[seed]
      end

      unless servers.empty?
        @dynamic_seeds = servers.map(&:address)
      end

      true
    end

    def sync_server(server)
      [].tap do |hosts|
        socket = server.socket

        if socket.connect
          info = socket.simple_query Protocol::Command.new(:admin, ismaster: 1)

          if info["ismaster"]
            server.primary = true
          end

          if info["secondary"]
            server.secondary = true
          end

          if info["primary"]
            hosts.push info["primary"]
          end

          if info["hosts"]
            hosts.concat info["hosts"]
          end

          if info["passives"]
            hosts.concat info["passives"]
          end

          merge(server)

        end
      end.uniq
    end

    def merge(server)
      previous = servers.find { |other| other == server }
      primary = server.primary?
      secondary = server.secondary?

      if previous
        previous.merge(server)
      else
        servers << server
      end
    end

    # @param [:read, :write] mode the type of socket to return
    # @return [Socket] a socket valid for +mode+ operations
    def socket_for(mode)
      sync unless primaries.any? || (secondaries.any? && mode == :read)

      server = nil
      while primaries.any? || (secondaries.any? && mode == :read)
        if mode == :write || secondaries.empty?
          server = primaries.sample
        else
          server = secondaries.sample
        end

        if server
          socket = server.socket
          socket.connect unless socket.connection

          if socket.alive?
            break server
          else
            remove server
          end
        end
      end

      unless server
        raise Errors::ConnectionFailure.new("Could not connect to any primary or secondary servers")
      end

      socket = server.socket
      socket.apply_auth auth
      socket
    end

    # @return [Hash] the cached authentication credentials for this cluster.
    def auth
      @auth ||= {}
    end

    # Log in to +database+ with +username+ and +password+. Does not perform the
    # actual log in, but saves the credentials for later authentication on a
    # socket.
    def login(database, username, password)
      auth[database.to_s] = [username, password]
    end

    # Log out of +database+. Does not perform the actual log out, but will log
    # out when the socket is used next.
    def logout(database)
      auth.delete(database.to_s)
    end

  end

end
