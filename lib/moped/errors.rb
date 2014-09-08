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

    # @api private
    #
    # Exception indicating that replica set was most likely reconfigured
    class ReplicaSetReconfigured < MongoError; end

    # Exception raised when database responds with 'not master' error
    class NotMaster < ReplicaSetReconfigured; end

    # Exception raised when authentication fails.
    class AuthenticationFailure < MongoError; end

    # Exception raised when authorization fails.
    class AuthorizationFailure < MongoError; end

    # Exception raised when operation fails
    class OperationFailure < MongoError

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

    # Exception raised on invalid queries.
    class QueryFailure < MongoError; end

    # Exception raised if the cursor could not be found.
    class CursorNotFound < MongoError
      def initialize(operation, cursor_id)
        super(operation, {"errmsg" => "cursor #{cursor_id} not found"})
      end
    end

    # Tag applied to unhandled exceptions on a node.
    module SocketError; end
  end
end
