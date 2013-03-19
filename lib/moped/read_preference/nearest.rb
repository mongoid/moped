# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a nearest read preference.
    #
    # @since 2.0.0
    class Nearest
      include Selectable

      # Get the name for the read preference on the server side.
      #
      # @example Get the name of the read preference.
      #   nearest.name
      #
      # @return [ Symbol ] :nearest.
      #
      # @since 2.0.0
      def name
        :nearest
      end

      # Execute the provided block on the node with the lowest latency,
      # allowing either primary or secondary.
      #
      # @example Read from the nearest node in the cluster.
      #   preference.with_node(cluster) do |node|
      #     node.command(ismaster: 1)
      #   end
      #
      # @note If tag sets are provided then selection will need to
      #   match the provided tags.
      #
      # @param [ Cluster ] cluster The cluster of nodes to select from.
      # @param [ Proc ] block The block to execute on the node.
      #
      # @raise [ Errors::ConnectionFailure ] If no node was available in the
      #   cluster.
      #
      # @return [ Object ] The result of the block.
      #
      # @since 2.0.0
      def with_node(cluster, &block)
        with_retry(cluster) do
          nearest = cluster.nodes.sort_by(&:latency).first
          if nearest
            block.call(nearest)
          else
            raise Errors::ConnectionFailure, "No nodes available to select in the cluster"
          end
        end
      end
    end
  end
end
