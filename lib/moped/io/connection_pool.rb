# encoding: utf-8
require "monitor"

module Moped
  module IO

    # This class contains behaviour of a pool of connections.
    #
    # @since 2.0.0
    class ConnectionPool
      include MonitorMixin

      # The default max size for the connection pool.
      MAX_SIZE = 5

      # The default timeout for getting connections from the queue.
      TIMEOUT = 0.25

      # @!attribute host
      #   @return [ String ] The host the pool is for.
      # @!attribute port
      #   @return [ Integer ] The port on the host.
      # @!attribute options
      #   @return [ Hash ] The connection pool options.
      attr_reader :host, :port, :options

      def checkin(connection)
        synchronize do
          unpinned.push(connection)
        end
      end

      def checkout
        synchronize do
          connection = @unpinned.pop(timeout)
          return connection if connection
          create_connection!
        end
      end

      # Get a connection. Will try pinned connections first then will attempt
      # to checkout a new one.
      #
      # @example Get a connection from the pool.
      #   pool.connection
      #
      # @return [ Connection ] A connection from the pool.
      #
      # @since 2.0.0
      def connection
        # @todo: Cleanup connections for dead threads first?
        pinned[Thread.current.object_id] ||= checkout
      end

      # Initialize the connection pool.
      #
      # @example Instantiate the connection pool.
      #   ConnectionPool.new(max_size: 4)
      #
      # @param [ Hash ] options The connection pool options.
      #
      # @since 2.0.0
      def initialize(host, port, options = {})
        super()
        @host = host
        @port = port
        @options = options
        @pinned = ThreadSafe::Cache.new(initial_capacity: max_size)
        @unpinned = Queue.new(self)
      end

      # Get the max size for the connection pool.
      #
      # @example Get the max size.
      #   pool.max_size
      #
      # @return [ Integer ] The max size of the pool.
      #
      # @since 2.0.0
      def max_size
        @max_size ||= (options[:max_size] || MAX_SIZE)
      end

      # Is the pool saturated - are the number of pinned and unpinned
      # connections at max value.
      #
      # @example Is the queue saturated.
      #   pool.saturated?
      #
      # @return [ true, false ] If the pool is saturated.
      #
      # @since 2.0.0
      def saturated?
        synchronize do
          (pinned.size + unpinned.size) >= max_size
        end
      end

      # Get the timeout when attempting to check out items from the pool.
      #
      # @example Get the checkout timeout.
      #   pool.timeout
      #
      # @return [ Float ] The pool timeout.
      #
      # @since 2.0.0
      def timeout
        @timeout ||= (options[:pool_timeout] || TIMEOUT)
      end

      private

      # @!attribute pinned
      #   @return [ ThreadSafe::Cache ] The pinned connections to threads.
      # @!attribute unpinned
      #   @return [ Queue ] The unpinned available connections.
      attr_reader :pinned, :unpinned

      # Create a new connection if the pool is not saturated.
      #
      # @api private
      #
      # @example Create a new connection.
      #   pool.create_connection!
      #
      # @return [ Connection ] The fresh connection.
      #
      # @since 2.0.0
      def create_connection!
        if saturated?
          # raise an error here.
        else
          Connection.new(host, port, options[:timeout], options)
        end
      end

      def release(connection)
        pinned.delete(Thread.current.object_id)
        checkin(connection)
      end
    end
  end
end
