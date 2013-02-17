module Moped

  # The cluster represents a cluster of MongoDB server nodes, either a single
  # node, a replica set, or a mongos server.
  class Cluster

    # @attribute [r] options The cluster options.
    # @attribute [r] seeds The seeds the cluster was initialized with.
    attr_reader :options, :seeds

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
      nodes(include_arbiters: true).each { |node| node.disconnect } and true
    end

    # Get the interval at which a node should be flagged as down before
    # retrying.
    #
    # @example Get the down interval, in seconds.
    #   cluster.down_interval
    #
    # @return [ Integer ] The down interval.
    #
    # @since 1.2.7
    def down_interval
      options[:down_interval]
    end

    # Get the number of times an operation should be retried before raising an
    # error.
    #
    # @example Get the maximum retries.
    #   cluster.max_retries
    #
    # @return [ Integer ] The max retries.
    #
    # @since 1.2.7
    def max_retries
      options[:max_retries]
    end

    # Get the interval in which the node list should be refreshed.
    #
    # @example Get the refresh interval, in seconds.
    #   cluster.refresh_interval
    #
    # @return [ Integer ] The refresh interval.
    #
    # @since 1.2.7
    def refresh_interval
      options[:refresh_interval]
    end

    # Get the operation retry interval - the time to wait before retrying a
    # single operation.
    #
    # @example Get the retry interval, in seconds.
    #   cluster.retry_interval
    #
    # @return [ Integer ] The retry interval.
    #
    # @since 1.2.7
    def retry_interval
      options[:retry_interval]
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
    # @option options [ Integer ] :timeout The time in seconds to wait for an
    #   operation to timeout. (5)
    #
    # @since 1.0.0
    def initialize(hosts, options)
      @seeds = hosts
      @nodes = hosts.map { |host| Node.new(host, options) }
      @peers = []

      @options = {
        down_interval: 30,
        max_retries: 20,
        refresh_interval: 300,
        retry_interval: 0.25
      }.merge(options)
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
    def nodes(opts = {})
      current_time = Time.new
      down_boundary = current_time - down_interval
      refresh_boundary = current_time - refresh_interval

      # Find the nodes that were down but are ready to be refreshed, or those
      # with stale connection information.
      needs_refresh, available = @nodes.partition do |node|
        node.down? ? (node.down_at < down_boundary) : node.needs_refresh?(refresh_boundary)
      end

      # Refresh those nodes.
      available.concat refresh(needs_refresh)

      # Now return all the nodes that are available and participating in the
      # replica set.
      available.reject do |node|
        node.down? || !member?(node) || (!opts[:include_arbiters] && node.arbiter?)
      end
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

            # Now refresh any newly discovered peer nodes - this will also
            # remove nodes that are not included in the peer list.
            refresh_peers(node, &refresh_node)
          rescue Errors::ConnectionFailure
            # We couldn't connect to the node.
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
    # @param [ Integer ] retries The number of times to retry.
    #
    # @raises [ ConnectionFailure ] When no primary node can be found
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 1.0.0
    def with_primary(retries = max_retries, &block)
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

      if retries > 0
        # We couldn't find a primary node, so refresh the list and try again.
        sleep(retry_interval)
        refresh
        with_primary(retries - 1, &block)
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
    # @param [ Integer ] retries The number of times to retry.
    #
    # @raises [ ConnectionFailure ] When no primary node can be found
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 1.0.0
    def with_secondary(retries = max_retries, &block)
      available_nodes = nodes.shuffle!.partition(&:secondary?).flatten

      while node = available_nodes.shift
        begin
          return yield node.apply_auth(auth)
        rescue Errors::ConnectionFailure
          # That node's no good, so let's try the next one.
          next
        end
      end

      if retries > 0
        # We couldn't find a secondary or primary node, so refresh the list and
        # try again.
        sleep(retry_interval)
        refresh
        with_secondary(retries - 1, &block)
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

    def member?(node)
      @peers.empty? || @peers.include?(node)
    end

    def refresh_peers(node, &block)
      peers = node.peers
      return if !peers || peers.empty?
      peers.each do |node|
        block.call(node) unless @nodes.include?(node)
        @peers.push(node) unless peers.include?(node)
      end
    end
  end
end
