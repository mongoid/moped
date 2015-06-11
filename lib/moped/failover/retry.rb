# encoding: utf-8
module Moped
  module Failover

    # Retry is for the case when we get exceptions around the connection, and
    # want to make another attempt to try and resolve the issue.
    #
    # @since 2.0.0
    module Retry
      extend self

      # Executes the failover strategy. In the case of retry, we disconnect and
      # reconnect, then try the operation one more time.
      #
      # @example Execute the retry strategy.
      #   Moped::Failover::Retry.execute(exception, node)
      #
      # @param [ Exception ] exception The raised exception.
      # @param [ Node ] node The node the exception got raised on.
      #
      # @raise [ Errors::ConnectionFailure ] If the retry fails.
      #
      # @return [ Object ] The result of the block yield.
      #
      # @since 2.0.0
      def execute(exception, node)
        node.disconnect unless exception.is_a?(Errors::PoolTimeout)
        begin
          node.connection do |conn|
            yield(conn) if block_given?
          end
        rescue Errors::PoolTimeout => e
          raise Errors::ConnectionFailure.new e
        rescue Exception => e
          node.down!
          raise(e)
        end
      end
    end
  end
end
