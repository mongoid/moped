# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a secondary read preference.
    #
    # @since 2.0.0
    class Secondary
      include Selectable

      # Get the name for the read preference on the server side.
      #
      # @example Get the name of the read preference.
      #   secondary.name
      #
      # @return [ Symbol ] :secondary.
      #
      # @since 2.0.0
      def name
        :secondary
      end

      # Select a secondary node from the cluster. If no secondary is available then
      # an exception will be raised.
      #
      # @example Read from a secondary node from the cluster.
      #   preference.with_node(cluster) do |node|
      #     node.command(ismaster: 1)
      #   end
      #
      # @note If tag sets are provided then secondary selection will need to
      #   match the provided tags.
      #
      # @param [ Cluster ] cluster The cluster of nodes to select from.
      # @param [ Proc ] block The block to execute on the node.
      #
      # @raise [ Errors::ConnectionFailure ] If no secondary node was available
      #   in the cluster.
      #
      # @return [ Object ] The result of the block.
      #
      # @since 2.0.0
      def with_node(cluster, &block)
        with_retry(cluster) do
          cluster.with_secondary(&block)
        end
      end
    end
  end
end
