module Moped

  # The connection pool represents a fixed number of connections in a single
  # runtime that can be used. If the maximum number is exhausted then we will
  # block until one becomes available.
  #
  # @since 2.0.0
  class ConnectionPool

    attr_reader :queue

    # Execute a block on a connection from the pool.
    #
    # @example Execute a block on a connection.
    #   pool.with_connection do |conn|
    #     conn.read
    #   end
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 2.0.0
    def with_connection
      connection = queue.pop
      begin
        yield(connection)
      ensure
        queue.push(connection)
      end
    end

    # Initialize the connection pool.
    #
    # @example Initialize the connection pool.
    #   Moped::ConnectionPool.new("127.0.0.1", 27017, 30, 50)
    #
    # @param [ String ] host The host to connect to.
    # @param [ Integer ] port The port to connect to.
    # @param [ Integer ] timeout The timeout in seconds.
    # @param [ Hash ] options The connection options.
    #
    # @since 2.0.0
    def initialize(host, port, timeout, options = {})
      @queue = Queue.new(options[:pool_size]) do
        Connection.new(host, port, timeout, options)
      end
    end

    private

    class Queue

      attr_reader :connections, :mutex, :resource

      # Initialize a new.
      #
      # @example Initialize a new queue.
      #   Queue.new(10) do
      #     Connection.new
      #   end
      #
      # @param [ Integer ] pool_size The number of items in the queue.
      #
      # @since 2.0.0
      def initialize(pool_size)
        @mutex = Mutex.new
        @resource = ConditionVariable.new
        @connections = Array.new(pool_size) { yield }
      end

      # Pop a connection off the queue.
      #
      # @example Pop a connection off the queue.
      #   queue.pop
      #
      # @return [ Connection ] A connection.
      #
      # @since 2.0.0
      def pop
        mutex.synchronize do
          loop do
            return connections.pop unless connections.empty?
            resource.wait(mutex)
          end
        end
      end

      # Push a connection onto the queue.
      #
      # @example Push a connection onto the queue.
      #   queue.push(connection)
      #
      # @param [ Connection ] The connection to add.
      #
      # @since 2.0.0
      def push(connection)
        mutex.synchronize do
          connections.push(connection)
          resource.broadcast
        end
      end
    end
  end
end
