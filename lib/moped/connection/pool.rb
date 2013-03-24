# encoding: utf-8
module Moped
  class Connection

    # This class contains behaviour of connection pools for specific addresses.
    #
    # @since 2.0.0
    class Pool

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

      # Checkout a connection from the connection pool. If there exists a
      # connection pinned to the current thread, then we return that first. If
      # no connection is pinned, we will take an unpinned connection or create
      # a new one if no unpinned exist and the pool is not saturated.
      #
      # @example Checkout a connection.
      #   pool.checkout
      #
      # @return [ Connection ] A connection.
      #
      # @since 2.0.0
      def checkout
        mutex.synchronize do
          conn = pinned[thread_id] ||= (unpinned.pop || create_connection)
          conn.lease
          conn
        end
      end

      def checkin(connection)
        mutex.synchronize do
          connection.expire
          unpinned.push(connection)
        end
      end

      # Initialize the connection pool.
      #
      # @example Instantiate the connection pool.
      #   Pool.new(max_size: 4)
      #
      # @param [ Hash ] options The connection pool options.
      #
      # @since 2.0.0
      def initialize(host, port, options = {})
        @host = host
        @port = port
        @options = options
        @mutex = Mutex.new
        @resource = ConditionVariable.new
        @pinned = {}
        @unpinned = []
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

      def size
        unpinned.size + pinned.size
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

      attr_reader :mutex, :resource, :pinned, :unpinned

      def create_connection
        Connection.new(host, port, options[:timeout], options)
      end

      def thread_id
        Thread.current.object_id
      end
    end
  end
end
