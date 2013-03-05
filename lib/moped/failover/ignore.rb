# encoding: utf-8
module Moped
  module Failover

    # Ignore is for the case when we get exceptions we deem are proper user
    # or datbase errors and should be re-raised.
    #
    # @since 2.0.0
    module Ignore
      extend self

      # Executes the failover strategy. In the case of ignore, we just re-raise
      # the exception that was thrown previously.
      #
      # @example Execute the ignore strategy.
      #   ignore.execute(exception, node)
      #
      # @param [ Exception ] exception The raised exception.
      # @param [ Node ] node The node the exception got raised on.
      # @param [ Proc ] block The optional block.
      #
      # @raise [ Exception ] The exception that was previously thrown.
      #
      # @since 2.0.0
      def execute(exception, node, &block)
        raise(exception)
      end
    end
  end
end
