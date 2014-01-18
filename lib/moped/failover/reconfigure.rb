# encoding: utf-8
module Moped
  module Failover

    # Reconfigure is for exceptions that indicate that a replica set was
    # potentially reconfigured in the middle of an operation.
    #
    # @since 2.0.0
    module Reconfigure
      extend self

      # Executes the failover strategy. In the case of reconfigure, we check if
      # the failure was due to a replica set reconfiguration mid operation and
      # raise a new error if appropriate.
      #
      # @example Execute the reconfigure strategy.
      #   Moped::Failover::Reconfigure.execute(exception, node)
      #
      # @param [ Exception ] exception The raised exception.
      # @param [ Node ] node The node the exception got raised on.
      #
      # @raise [ Exception, Errors::ReplicaSetReconfigure ] The exception that
      #   was previously thrown or a reconfiguration error.
      #
      # @since 2.0.0
      def execute(exception, node)
        if exception.reconfiguring_replica_set?
          raise(Errors::ReplicaSetReconfigured.new(exception.command, exception.details))
        elsif exception.connection_failure?
          raise Errors::ConnectionFailure.new(exception.inspect)
        end
        raise(exception)
      end
    end
  end
end
