# encoding: utf-8
module Moped
  class Connection

    # This class contains behaviour of a queue of unpinned connections.
    #
    # @since 2.0.0
    class Queue

      def initialize(size)
        @queue = Array.new(size) { yield }
        @mutex = Mutex.new
        @resource = ConditionVariable.new
      end

      def push(connection)
        mutex.synchronize do
          queue.push(connection)
          resource.broadcast
        end
      end

      def pop(timeout = 0.5)
        mutex.synchronize do
          wait_for_next(Time.now + timeout)
        end
      end

      def empty?
        queue.empty?
      end

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
