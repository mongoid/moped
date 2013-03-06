# encoding: utf-8
module Moped
  module Failover

    # Disconnect is for the case when we get exceptions we do not know about,
    # and need to disconnect the node to cleanup the problem.
    #
    # @since 2.0.0
    module Disconnect
      extend self

      # Executes the failover strategy. In the case of disconnect, we just re-raise
      # the exception that was thrown previously extending a socket error and
      # disconnect.
      #
      # @example Execute the disconnect strategy.
      #   Moped::Failover::Disconnect.execute(exception, node)
      #
      # @param [ Exception ] exception The raised exception.
      # @param [ Node ] node The node the exception got raised on.
      #
      # @raise [ Errors::SocketError ] The extended exception that was thrown.
      #
      # @since 2.0.0
      def execute(exception, node)
        node.disconnect
        raise(exception.extend(Errors::SocketError))
      end
    end
  end
end
