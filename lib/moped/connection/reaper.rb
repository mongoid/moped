# encoding: utf-8
module Moped
  class Connection

    # This object cleans up connections on dead threads at a specified time
    # interval.
    #
    # @since 2.0.0
    class Reaper

      # The default interval for reaping connections.
      #
      # @since 2.0.0
      INTERVAL = 5

      # @!attribute interval
      #   @return [ Float ] The reaping interval, in seconds.
      # @!attribute pool
      #   @return [ Pool ] The connection pool to reap.
      attr_reader :interval, :pool

      # Initialize a new connection pool reaper.
      #
      # @example Initialize the reaper.
      #   Moped::Connection::Reaper.new(5, pool)
      #
      # @param [ Float ] interval The reaping interval.
      # @param [ Pool ] pool The connection pool to reap.
      #
      # @since 2.0.0
      def initialize(interval, pool)
        @interval = interval
        @pool = pool
      end

      # Start the reaper. Will execute continually on a separate thread.
      #
      # @example Start the reaper.
      #   reaper.start
      #
      # @since 2.0.0
      def start
        Thread.new(interval, pool) do |i, p|
          while (true)
            sleep(i)
            p.reap
          end
        end
      end
    end
  end
end
