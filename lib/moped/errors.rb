module Moped
  module Errors

    # Mongo's exceptions are sparsely documented, but this is the most accurate
    # source of information on error codes.
    ERROR_REFERENCE = "https://github.com/mongodb/mongo/blob/master/docs/errors.md"

    # Raised when the connection pool is saturated and no new connection is
    # reaped during the wait time.
    class PoolSaturated < RuntimeError; end

    # Raised when attempting to checkout a connection on a thread that already
    # has a connection checked out.
    class ConnectionInUse < RuntimeError; end

    # Raised when attempting to checkout a pinned connection from the pool but
    # it is already in use by another object on the same thread.
    class PoolTimeout < RuntimeError; end

    # Generic error class for exceptions related to connection failures.
    class ConnectionFailure < StandardError; end

    # Raised when a database name is invalid.
    class InvalidDatabaseName < StandardError; end

    # Raised when a Mongo URI is invalid.
    class InvalidMongoURI < StandardError; end

    # Raised when providing an invalid string from an object id.
    class InvalidObjectId < StandardError

      # Create the new error.
      #
      # @example Create the new error.
      #   InvalidObjectId.new("test")
      #
      # @param [ String ] string The provided id.
      #
      # @since 1.0.0
      def initialize(string)
        super("'#{string}' is not a valid object id.")
      end
    end

    # Generic error class for exceptions generated on the remote MongoDB
    # server.
    class MongoError < StandardError

      # @attribute [r] details The details about the error.
      # @attribute [r] command The command that generated the error.
      attr_reader :details, :command

      # Create a new operation failure exception.
      #
      # @example Create the new error.
      #   MongoError.new(command, details)
      #
      # @param [ Object ] command The command that generated the error.
      # @param [ Hash ] details The details about the error.
      #
      # @since 1.0.0
      def initialize(command, details)
        @command, @details = command, details
        super(build_message)
      end

      private

      # Build the error message.
      #
      # @api private
      #
      # @example Build the message.
      #   error.build_message
      #
      # @return [ String ] The message.
      #
      # @since 1.0.0
      def build_message
        "The operation: #{command.inspect}\n#{error_message}"
      end

      # Get the error message.
      #
      # @api private
      #
      # @example Get the error message.
      #   error.error_message
      #
      # @return [ String ] The message.
      #
      # @since 1.0.0
      def error_message
        err = details["err"] || details["errmsg"] || details["$err"]
        if code = details["code"]
          "failed with error #{code}: #{err.inspect}\n\n" <<
            "See #{ERROR_REFERENCE}\nfor details about this error."
        elsif code = details["assertionCode"]
          assertion = details["assertion"]
          "failed with error #{code}: #{assertion.inspect}\n\n" <<
            "See #{ERROR_REFERENCE}\nfor details about this error."
        else
          "failed with error #{err.inspect}"
        end
      end
    end

    # Classes of errors that should not disconnect connections.
    class DoNotDisconnect < MongoError; end

    # Classes of errors that could be caused by a replica set reconfiguration.
    class PotentialReconfiguration < MongoError

      # Not master error codes.
      NOT_MASTER = [ 13435, 13436, 10009 ]

      # Error codes received around reconfiguration
      CONNECTION_ERRORS_RECONFIGURATION = [ 15988, 10276, 11600, 9001 ]

      # Replica set reconfigurations can be either in the form of an operation
      # error with code 13435, or with an error message stating the server is
      # not a master. (This encapsulates codes 10054, 10056, 10058)
      def reconfiguring_replica_set?
        err = details["err"] || details["errmsg"] || details["$err"] || ""
        NOT_MASTER.include?(details["code"]) || err.include?("not master")
      end

      def connection_failure?
        CONNECTION_ERRORS_RECONFIGURATION.include?(details["code"])
      end

      # Is the error due to a namespace not being found?
      #
      # @example Is the namespace not found?
      #   error.ns_not_found?
      #
      # @return [ true, false ] If the namespace was not found.
      #
      # @since 2.0.0
      def ns_not_found?
        details["errmsg"] == "ns not found"
      end

      # Is the error due to a namespace not existing?
      #
      # @example Doest the namespace not exist?
      #   error.ns_not_exists?
      #
      # @return [ true, false ] If the namespace was not found.
      #
      # @since 2.0.0
      def ns_not_exists?
        details["errmsg"] =~ /namespace does not exist/
      end
    end

    # Exception raised when authentication fails.
    class AuthenticationFailure < DoNotDisconnect; end

    # Exception class for exceptions generated as a direct result of an
    # operation, such as a failed insert or an invalid command.
    class OperationFailure < PotentialReconfiguration; end

    # Exception raised on invalid queries.
    class QueryFailure < PotentialReconfiguration; end

    # Exception raised if the cursor could not be found.
    class CursorNotFound < DoNotDisconnect
      def initialize(operation, cursor_id)
        super(operation, {"errmsg" => "cursor #{cursor_id} not found"})
      end
    end

    # @api private
    #
    # Internal exception raised by Node#ensure_primary and captured by
    # Cluster#with_primary.
    class ReplicaSetReconfigured < DoNotDisconnect; end

    # Tag applied to unhandled exceptions on a node.
    module SocketError; end
  end
end
