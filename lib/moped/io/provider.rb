# encoding: utf-8
module Moped
  module IO

    # This class provides thread safe access to multiple connection pools,
    # one per resolved address or node.
    #
    # @since 2.0.0
    module Provider
      extend self

      # Used for synchronization of pools access.
      MUTEX = Mutex.new

      # Get a connection pool for the provided node.
      #
      # @example Get a connection pool for the node.
      #   Provider.pool(node)
      #
      # @param [ Node ] The node.
      #
      # @return [ ConnectionPool ] The connection pool for the Node.
      #
      # @since 2.0.0
      def pool(node)
        pools[node.address.resolved] ||= ConnectionPool.new
      end

      private

      # Get all the connection pools. This is a cache that stores each pool
      # with lookup by it's resolved address.
      #
      # @api private
      #
      # @example Get the pools.
      #   Provider.pools
      #
      # @return [ ThreadSafe::Cache ] The cache of pools.
      #
      # @since 2.0.0
      def pools
        MUTEX.synchronize do
          @pools ||= ThreadSafe::Cache.new
        end
      end
    end
  end
end
