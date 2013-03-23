# encoding: utf-8
module Moped
  module IO

    # This class contains behaviour of a pool of connections.
    #
    # @since 2.0.0
    class ConnectionPool

      # The default max size for the connection pool.
      MAX_SIZE = 5

      # @!attribute options
      #   @return [ Hash ] The connection pool options.
      attr_reader :options

      def checkin(connection)

      end

      def checkout

      end

      def initialize(options = {})
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
    end
  end
end
