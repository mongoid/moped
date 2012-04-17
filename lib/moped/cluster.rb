module Moped

  class Cluster

    # @return [Array<String>] the seeds the replica set was initialized with
    attr_reader :seeds

    # @option options :down_interval number of seconds to wait before attempting
    # to reconnect to a down node. (30)
    #
    # @option options :refresh_interval number of seconds to cache information
    # about a node. (300)
    def initialize(hosts, options)
      @options = {
        down_interval: 30,
        refresh_interval: 300
      }.merge(options)

      @seeds = hosts
      @nodes = hosts.map { |host| Node.new(host) }
    end

    # Refreshes information for each of the nodes provided. The node list
    # defaults to the list of all known nodes.
    #
    # If a node is successfully refreshed, any newly discovered peers will also
    # be refreshed.
    #
    # @return [Array<Node>] the available nodes
    def refresh(nodes_to_refresh = @nodes)
      refreshed_nodes = []
      seen = {}

      # Set up a recursive lambda function for refreshing a node and it's peers.
      refresh_node = ->(node) do
        return if seen[node]
        seen[node] = true

        # Add the node to the global list of known nodes.
        @nodes << node unless @nodes.include?(node)

        begin
          node.refresh

          # This node is good, so add it to the list of nodes to return.
          refreshed_nodes << node unless refreshed_nodes.include?(node)

          # Now refresh any newly discovered peer nodes.
          (node.peers - @nodes).each &refresh_node
        rescue Errors::ConnectionFailure
          # We couldn't connect to the node, so don't do anything with it.
        end
      end

      nodes_to_refresh.each &refresh_node
      refreshed_nodes.to_a
    end

    # Returns the list of available nodes, refreshing 1) any nodes which were
    # down and ready to be checked again and 2) any nodes whose information is
    # out of date.
    #
    # @return [Array<Node>] the list of available nodes.
    def nodes
      # Find the nodes that were down but are ready to be refreshed, or those
      # with stale connection information.
      needs_refresh, available = @nodes.partition do |node|
        (node.down? && node.down_at < (Time.new - @options[:down_interval])) ||
          node.needs_refresh?(Time.new - @options[:refresh_interval])
      end

      # Refresh those nodes.
      available.concat refresh(needs_refresh)

      # Now return all the nodes that are available.
      available.reject &:down?
    end

    # Yields the replica set's primary node to the provided block. This method
    # will retry the block in case of connection errors or replica set
    # reconfiguration.
    #
    # @raises ConnectionFailure when no primary node can be found
    def with_primary(retry_on_failure = true, &block)
      if node = nodes.find(&:primary?)
        begin
          node.ensure_primary do
            return yield node.apply_auth(auth)
          end
        rescue Errors::ConnectionFailure, Errors::ReplicaSetReconfigured
          # Fall through to the code below if our connection was dropped or the
          # node is no longer the primary.
        end
      end

      if retry_on_failure
        # We couldn't find a primary node, so refresh the list and try again.
        refresh
        with_primary(false, &block)
      else
        raise Errors::ConnectionFailure, "Could not connect to a primary node for replica set #{inspect}"
      end
    end

    # Yields a secondary node if available, otherwise the primary node. This
    # method will retry the block in case of connection errors.
    #
    # @raises ConnectionError when no secondary or primary node can be found
    def with_secondary(retry_on_failure = true, &block)
      available_nodes = nodes.shuffle!.partition(&:secondary?).flatten

      while node = available_nodes.shift
        begin
          return yield node.apply_auth(auth)
        rescue Errors::ConnectionFailure
          # That node's no good, so let's try the next one.
          next
        end
      end

      if retry_on_failure
        # We couldn't find a secondary or primary node, so refresh the list and
        # try again.
        refresh
        with_secondary(false, &block)
      else
        raise Errors::ConnectionFailure, "Could not connect to any secondary or primary nodes for replica set #{inspect}"
      end
    end

    # @return [Hash] the cached authentication credentials for this cluster.
    def auth
      @auth ||= {}
    end

    private

    def initialize_copy(_)
      @nodes = @nodes.map &:dup
    end

  end
end
