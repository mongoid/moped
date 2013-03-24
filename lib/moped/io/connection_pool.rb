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
        if block_given?
          yield(checkout)
        else
          p "checking out..."
          checkout
        end
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

      def reap
        unpin(Thread.current.object_id)
        # if conn.in_use? && stale > conn.last_use && !conn.active?
          # remove conn
        # end
      end

      private

      # @!attribute pinned
      #   @return [ ThreadSafe::Cache ] The pinned connections to threads.
      # @!attribute unpinned
      #   @return [ Queue ] The unpinned available connections.
      attr_reader :pinned, :unpinned

      def active_threads
        Thread.list.find_all(&:alive?)
      end

      def checkin(connection)
        synchronize do
          unpinned.push(connection)
        end
      end

      def checkout
        synchronize do
          conn = pinned[Thread.current.object_id] ||= @unpinned.pop(timeout)
          conn || create_connection!
        end
      end

      def unpin_dead_threads!
        dead_threads = active_threads.map(&:object_id) - pinned.keys
        dead_threads.each{ |thread_id| unpin(thread_id) }
      end

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
        unpin_dead_threads!
        if saturated?
          raise RuntimeError, "Pool is saturated."
        else
          Connection.new(host, port, options[:timeout], options)
        end
      end

      # Is the pool saturated - are the number of pinned and unpinned
      # connections at max value.
      #
      # @api private
      #
      # @example Is the queue saturated.
      #   pool.saturated?
      #
      # @return [ true, false ] If the pool is saturated.
      #
      # @since 2.0.0
      def saturated?
        (pinned.size + unpinned.size) >= max_size
      end

      def unpin(thread_id)
        if connection = pinned.delete(thread_id)
          unpinned.push(connection)
        end
      end
    end
  end
end
