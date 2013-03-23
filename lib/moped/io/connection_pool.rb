# encoding: utf-8
module Moped
  module IO

    # This class contains behaviour of a pool of connections.
    #
    # @since 2.0.0
    class ConnectionPool

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
        @unpinned.push(connection)
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
        @host = host
        @port = port
        @options = options
        @pinned = ThreadSafe::Cache.new(initial_capacity: max_size)
        @unpinned = Queue.new
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
        (@pinned.size + @unpinned.size) >= max_size
      end

      def timeout
        @timeout ||= (options[:pool_timeout] || TIMEOUT)
      end

      def with_connection
        begin
          yield(connection)
        ensure
          release(connection)
        end
      end

      private

      def checkout
        connection = @unpinned.pop(timeout)
        return connection if connection
        create_connection!
      end

      def create_connection!
        if saturated?
          # raise an error here.
        else
          Connection.new(host, port, options[:timeout], options)
        end
      end

      def connection
        @pinned[Thread.current.object_id] ||= checkout
      end

      def release(connection)
      end
    end
  end
end
