# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a primary read preference.
    #
    # @since 2.0.0
    class Primary
      include Selectable

      # Get the name for the read preference on the server side.
      #
      # @example Get the name of the read preference.
      #   primary.name
      #
      # @return [ Symbol ] :primary.
      #
      # @since 2.0.0
      def name
        :primary
      end

      # Get the provided options as query options for this read preference.
      #
      # @example Get the query options.
      #   preference.query_options({})
      #
      # @param [ Hash ] options The existing options for the query.
      #
      # @return [ Hash ] The options plus additional query options.
      #
      # @since 2.0.0
      def query_options(options)
        options
      end

      # Select a primary node from the cluster. If no primary node is available
      # then an exception will be raised.
      #
      # @example Select a primary node from the cluster.
      #   preference.with_node(cluster) do |node|
      #     node.command(ismaster: 1)
      #   end
      #
      # @param [ Cluster ] cluster The cluster of nodes to select from.
      # @param [ Proc ] block The block to execute on the node.
      #
      # @raise [ Errors::ConnectionFailure ] If no primary node was available in the cluster.
      #
      # @return [ Object ] The result of the block.
      #
      # @since 2.0.0
      def with_node(cluster, &block)
        with_retry(cluster) do
          cluster.with_primary(&block)
        end
      end
    end
  end
end
