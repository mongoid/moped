# encoding: utf-8
module Moped
  class Connection

    # This class contains behaviour of connection pools for specific addresses.
    #
    # @since 2.0.0
    class Pool

      # The default max size for the connection pool.
      POOL_SIZE = 5

      # The default timeout for getting connections from the queue.
      TIMEOUT = 0.25

      # @!attribute host
      #   @return [ String ] The host the pool is for.
      # @!attribute port
      #   @return [ Integer ] The port on the host.
      # @!attribute options
      #   @return [ Hash ] The connection pool options.
      # @!attribute reaper
      #   @return [ Reaper ] The connection pool reaper.
      attr_reader :host, :port, :options, :reaper

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
          connection = pinned[thread_id]
          if connection
            unless connection.expired?
              raise Errors::ConnectionInUse, "The connection on thread: #{thread_id} is in use."
            else
              lease(connection)
            end
          else
            connection = pinned[thread_id] = next_connection
            lease(connection)
          end
        end
      end

      # Checkin the connection, indicating that it is finished being used. The
      # connection will stay pinned to the current thread.
      #
      # @example Checkin the connection.
      #   pool.checkin(connection)
      #
      # @param [ Connection ] connection The connection to checkin.
      #
      # @since 2.0.0
      def checkin(connection)
        mutex.synchronize do
          expire(connection)
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
        @reaper = Reaper.new(options[:reap_interval] || Reaper::INTERVAL, self)
        @mutex = Mutex.new
        @resource = ConditionVariable.new
        @pinned = {}
        @unpinned = Queue.new(max_size) do
          Connection.new(host, port, options[:timeout] || Connection::TIMEOUT, options)
        end
        reaper.start
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
        @max_size ||= (options[:pool_size] || POOL_SIZE)
      end

      # Reap all connections that are active and associated with dead threads.
      #
      # @example Reap the connections.
      #   pool.reap([ 12351122313 ])
      #
      # @param [ Array<Integer> ] ids The ids of the current active threads.
      #
      # @return [ Pool ] The connection pool.
      #
      # @since 2.0.0
      def reap(ids = active_threads)
        pinned.each do |id, conn|
          unless ids.include?(id)
            conn.expire
            unpinned.push(pinned.delete(id))
          end
        end and self
      end

      # Get the current size of the connection pool. Is the total of pinned
      # plus unpinned connections.
      #
      # @example Get the pool's current size.
      #   pool.size
      #
      # @return [ Integer ] The current size of the pool.
      #
      # @since 2.0.0
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

      # Execute the block with a connection, ensuring that the checkin/checkout
      # workflow is properly executed.
      #
      # @example Execute the block with a connection.
      #   pool.with_connection do |conn|
      #     conn.connect
      #   end
      #
      # @return [ Object ] The result of the yield.
      #
      # @since 2.0.0
      def with_connection
        connection = checkout
        begin
          yield(connection)
        ensure
          checkin(connection)
        end
      end

      private

      attr_reader :mutex, :resource, :pinned, :unpinned

      def expire(connection)
        connection.expire
        pinned[thread_id] = connection
      end

      def lease(connection)
        connection.lease
        connection
      end

      def next_connection
        reap if saturated?
        unpinned.pop(timeout)
      end

      def saturated?
        size == max_size
      end

      def thread_id
        Thread.current.object_id
      end

      def active_threads
        Thread.list.select{ |thread| thread.alive? }.map{ |thread| thread.object_id }
      end
    end
  end
end
