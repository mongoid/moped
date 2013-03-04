# encoding: utf-8
module Moped
  module Failover

    # Ignore is for the case when we get exceptions we do not know about, or
    # exceptions we deem are proper user errors and should be re-raised.
    #
    # @since 2.0.0
    class Ignore

      # @!attribute exception
      #   @return [ Exception ] The raised exception.
      attr_reader :exception

      # Instantiate the new Ignore handler.
      #
      # @example Instantiate the new ignore handler.
      #   Moped::Failover::Ignore.new(exception)
      #
      # @param [ Exception ] exception The raised exception.
      #
      # @since 2.0.0
      def initialize(exception)
        @exception = exception
      end

      # Executes the failover strategy. In the case of ignore, we just re-raise
      # the exception that was thrown previously.
      #
      # @example Execute the ignore strategy.
      #   ignore.execute(node)
      #
      # @param [ Node ] node The node the exception got raised on.
      # @param [ Proc ] block The optional block.
      #
      # @raise [ Exception ] The exception that was previously thrown.
      #
      # @since 2.0.0
      def execute(node, &block)
        raise(exception)
      end
    end
  end
end
