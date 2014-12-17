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

      # Used for synchronization of pool shutdown.
      SHUTDOWN_MUTEX = Mutex.new

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

      # Shut down a pool for a node while immediately clearing
      # the cached pool so a new one can be created by another
      # thread.
      #
      # @example Shut down a pool for a node
      #   Manager.shutdown_pool(node, pool)
      #
      # @param [ Node ] The node.
      # @param [ ConnectionPool ] The current pool to shutdown.
      #
      # @return [ Boolean ] true.
      #
      # @since 2.0.3
      def shutdown_pool(node, pool)
        pool_id = "#{node.address.resolved}-#{pool.object_id}"

        SHUTDOWN_MUTEX.synchronize do 
          return if !!shutting_down[pool_id]
          Moped.logger.debug("MOPED: Shutting down connection pool:#{pool.object_id} for node:#{node.inspect}")
          shutting_down[pool_id] = true
          MUTEX.synchronize do
            pools[node.address.resolved] = nil
          end
        end

        begin
          if pool
            pool.shutdown {|conn| conn.disconnect }
          end
        ensure
          shutting_down[pool_id] = false
        end
        true
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
        Moped.logger.debug("MOPED: Creating new connection pool for #{node.inspect}")        

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

      # Used for tracking whether the current pool is already being shutdown
      # by another thread.
      #
      # @api private
      #
      # @example Determine if a pool is already being shutdown.
      #   Manager.shutting_down
      #
      # @return [ Hash ] The state of a pool shutting down.
      #
      # @since 2.0.3
      def shutting_down
        @shutting_down ||= {}
      end

    end
  end
end
