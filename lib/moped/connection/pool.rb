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
    end
  end
end
