# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a primary preferred read preference.
    #
    # @since 2.0.0
    class PrimaryPreferred
      include Selectable

      # Get the name for the read preference on the server side.
      #
      # @example Get the name of the read preference.
      #   primary_preferred.name
      #
      # @return [ Symbol ] :primaryPreferred.
      #
      # @since 2.0.0
      def name
        :primaryPreferred
      end

      # Select a primary node from the cluster. If no primary node is available
      # then attempt to select a secondary. If no secondary is available then
      # an exception will be raised.
      #
      # @example Prefer to with_node a primary node from the cluster.
      #   preference.with_node(cluster) do |node|
      #     node.command(ismaster: 1)
      #   end
      #
      # @note If tag sets are provided then secondary with_nodeion will need to
      #   match the provided tags.
      #
      # @param [ Cluster ] cluster The cluster of nodes to select from.
      # @param [ Proc ] block The block to execute on the node.
      #
      # @raise [ Errors::ConnectionFailure ] If no primary or secondary node was
      #   available in the cluster.
      #
      # @return [ Object ] The result of the block.
      #
      # @since 2.0.0
      def with_node(cluster, &block)
        with_retry(cluster) do
          begin
            cluster.with_primary(&block)
          rescue Errors::ConnectionFailure
            cluster.with_secondary(&block)
          end
        end
      end
    end
  end
end
