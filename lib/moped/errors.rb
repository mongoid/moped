module Moped
  module Errors

    # Mongo's exceptions are sparsely documented, but this is the most accurate
    # source of information on error codes.
    ERROR_REFERENCE = "https://github.com/mongodb/mongo/blob/master/docs/errors.md"

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
        else
          "failed with error #{err.inspect}"
        end
      end
    end

    # Exception raised when authentication fails.
    class AuthenticationFailure < MongoError; end

    # Exception class for exceptions generated as a direct result of an
    # operation, such as a failed insert or an invalid command.
    class OperationFailure < MongoError; end

    # Exception raised on invalid queries.
    class QueryFailure < MongoError; end

    # Exception raised if the cursor could not be found.
    class CursorNotFound < MongoError
      def initialize(operation, cursor_id)
        super(operation, {"errmsg" => "cursor #{cursor_id} not found"})
      end
    end

    # @api private
    #
    # Internal exception raised by Node#ensure_primary and captured by
    # Cluster#with_primary.
    class ReplicaSetReconfigured < StandardError; end

    # Tag applied to unhandled exceptions on a node.
    module SocketError; end
  end
end
