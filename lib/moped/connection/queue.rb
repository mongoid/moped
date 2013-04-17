# encoding: utf-8
module Moped
  class Connection

    # This class contains behaviour of a queue of unpinned connections.
    #
    # @since 2.0.0
    class Queue

      # Initialize a queue with the provided size.
      #
      # @example Instantiate the queue.
      #   Moped::Connection::Queue.new(10)
      #
      # @param [ Integer ] size The number of connections in the queue.
      #
      # @since 2.0.0
      def initialize(size)
        @queue = Array.new(size) { yield }
        @mutex = Mutex.new
        @resource = ConditionVariable.new
      end

      # Push a connection on the queue.
      #
      # @example Push a connection on the queue.
      #   queue.push(connection)
      #
      # @param [ Moped::Connection ] connection The connection to add.
      #
      # @since 2.0.0
      def push(connection)
        mutex.synchronize do
          queue.push(connection)
          resource.broadcast
        end
      end

      # Pop the next connection off the queue.
      #
      # @example Pop a connection off the queue.
      #   queue.pop(0.5)
      #
      # @param [ Float ] timeout The time to wait for the connection.
      #
      # @return [ Moped::Connection ] The next connection.
      #
      # @since 2.0.0
      def pop(timeout = 0.5)
        mutex.synchronize do
          wait_for_next(Time.now + timeout)
        end
      end

      # Is the queue empty?
      #
      # @example Is the queue empty?
      #   queue.empty?
      #
      # @return [ true, false ] Is the queue empty?
      #
      # @since 2.0.0
      def empty?
        queue.empty?
      end

      # Get the current size of the queue.
      #
      # @example Get the size of the queue.
      #   queue.size
      #
      # @return [ Integer ] The number of connections in the queue.
      #
      # @since 2.0.0
      def size
        queue.size
      end

      private

      attr_reader :queue, :mutex, :resource

      def wait_for_next(deadline)
        loop do
          return queue.pop unless queue.empty?
          wait = deadline - Time.now
          raise Timeout::Error, "Waited for item but none was pushed." if wait <= 0
          resource.wait(mutex, wait)
        end
      end
    end
  end
end
