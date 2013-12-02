# encoding: utf-8
require "connection_pool"

module Moped
  class Connection

    # This class contains behaviour of connection pools for specific addresses.
    #
    # @since 2.0.0
    module Manager
      extend self

      # Used for synchronization of pools access.
      MUTEX = Mutex.new

      # The default max size for the connection pool.
      POOL_SIZE = 5

      # The default timeout for getting connections from the queue.
      TIMEOUT = 0.5

      # Get a connection pool for the provided node.
      #
      # @example Get a connection pool for the node.
      #   Manager.pool(node)
      #
      # @param [ Node ] The node.
      #
      # @return [ Pool ] The connection pool for the Node.
      #
      # @since 2.0.0
      def pool(node)
        MUTEX.synchronize do
          pools[node.address.resolved] ||= create_pool(node)
        end
      end

      private

      # Create a new connection pool for the provided node.
      #
      # @api private
      #
      # @example Get a connection pool for the node.
      #   Manager.create_pool(node)
      #
      # @param [ Node ] node The node.
      #
      # @return [ ConnectionPool ] A connection pool.
      #
      # @since 2.0.0
      def create_pool(node)
        ConnectionPool.new(
          size: node.options[:pool_size] || POOL_SIZE,
          timeout: node.options[:pool_timeout] || TIMEOUT
        ) do
          Connection.new(
            node.address.ip,
            node.address.port,
            node.options[:timeout] || Connection::TIMEOUT,
            node.options
          )
        end
      end

      # Get all the connection pools. This is a cache that stores each pool
      # with lookup by it's resolved address.
      #
      # @api private
      #
      # @example Get the pools.
      #   Manager.pools
      #
      # @return [ Hash ] The cache of pools.
      #
      # @since 2.0.0
      def pools
        @pools ||= {}
      end
    end
  end
end
