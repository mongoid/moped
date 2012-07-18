module Moped

  # The cluster represents a cluster of MongoDB server nodes, either a single
  # node, a replica set, or a mongos server.
  class Cluster

    # @attribute [r] seeds The seeds the cluster was initialized with.
    attr_reader :seeds

    # Get the authentication details for the cluster.
    #
    # @example Get the authentication details.
    #   cluster.auth
    #
    # @return [ Hash ] the cached authentication credentials for this cluster.
    #
    # @since 1.0.0
    def auth
      @auth ||= {}
    end

    # Disconnects all nodes in the cluster. This should only be used in cases
    # where you know you're not going to use the cluster on the thread anymore
    # and need to force the connections to close.
    #
    # @return [ true ] True if the disconnect succeeded.
    #
    # @since 1.2.0
    def disconnect
      nodes.each { |node| node.disconnect } and true
    end

    # Initialize the new cluster.
    #
    # @example Initialize the cluster.
    #   Cluster.new([ "localhost:27017" ], down_interval: 20)
    #
    # @param [ Hash ] options The cluster options.
    #
    # @option options :down_interval number of seconds to wait before attempting
    #   to reconnect to a down node. (30)
    # @option options :refresh_interval number of seconds to cache information
    #   about a node. (300)
    #
    # @since 1.0.0
    def initialize(hosts, options)
      @options = {
        down_interval: 30,
        refresh_interval: 300
      }.merge(options)

      @seeds = hosts
      @nodes = hosts.map { |host| Node.new(host) }
    end

    # Returns the list of available nodes, refreshing 1) any nodes which were
    # down and ready to be checked again and 2) any nodes whose information is
    # out of date. Arbiter nodes are not returned.
    #
    # @example Get the available nodes.
    #   cluster.nodes
    #
    # @return [ Array<Node> ] the list of available nodes.
    #
    # @since 1.0.0
    def nodes
      current_time = Time.new
      down_boundary = current_time - @options[:down_interval]
      refresh_boundary = current_time - @options[:refresh_interval]

      # Find the nodes that were down but are ready to be refreshed, or those
      # with stale connection information.
      needs_refresh, available = @nodes.partition do |node|
        (node.down? && node.down_at < down_boundary) || node.needs_refresh?(refresh_boundary)
      end

      # Refresh those nodes.
      available.concat refresh(needs_refresh)

      # Now return all the nodes that are available and participating in the
      # replica set.
      available.reject { |node| node.down? || node.arbiter? }
    end

    # Refreshes information for each of the nodes provided. The node list
    # defaults to the list of all known nodes.
    #
    # If a node is successfully refreshed, any newly discovered peers will also
    # be refreshed.
    #
    # @example Refresh the nodes.
    #   cluster.refresh
    #
    # @param [ Array<Node> ] nodes_to_refresh The nodes to refresh.
    #
    # @return [ Array<Node> ] the available nodes
    #
    # @since 1.0.0
    def refresh(nodes_to_refresh = @nodes)
      refreshed_nodes = []
      seen = {}

      # Set up a recursive lambda function for refreshing a node and it's peers.
      refresh_node = ->(node) do
        unless seen[node]
          seen[node] = true

          # Add the node to the global list of known nodes.
          @nodes << node unless @nodes.include?(node)

          begin
            node.refresh

            # This node is good, so add it to the list of nodes to return.
            refreshed_nodes << node unless refreshed_nodes.include?(node)

            # Now refresh any newly discovered peer nodes.
            (node.peers - @nodes).each(&refresh_node)
          rescue Errors::ConnectionFailure
            # We couldn't connect to the node, so don't do anything with it.
          end
        end
      end

      nodes_to_refresh.each(&refresh_node)
      refreshed_nodes.to_a
    end

    # Yields the replica set's primary node to the provided block. This method
    # will retry the block in case of connection errors or replica set
    # reconfiguration.
    #
    # @example Yield the primary to the block.
    #   cluster.with_primary do |node|
    #     # ...
    #   end
    #
    # @param [ true, false ] retry_on_failure Whether to retry if an error was
    #   raised.
    #
    # @raises [ ConnectionFailure ] When no primary node can be found
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 1.0.0
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
        raise(
          Errors::ConnectionFailure,
          "Could not connect to a primary node for replica set #{inspect}"
        )
      end
    end

    # Yields a secondary node if available, otherwise the primary node. This
    # method will retry the block in case of connection errors.
    #
    # @example Yield the secondary to the block.
    #   cluster.with_secondary do |node|
    #     # ...
    #   end
    #
    # @param [ true, false ] retry_on_failure Whether to retry if an error was
    #   raised.
    #
    # @raises [ ConnectionFailure ] When no primary node can be found
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 1.0.0
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
        raise(
          Errors::ConnectionFailure,
          "Could not connect to any secondary or primary nodes for replica set #{inspect}"
        )
      end
    end

    def inspect
      "<#{self.class.name} nodes=#{@nodes.inspect}>"
    end

    private

    def initialize_copy(_)
      @nodes = @nodes.map(&:dup)
    end
  end
end
