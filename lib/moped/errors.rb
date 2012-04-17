module Moped
  module Errors

    # Mongo's exceptions are sparsely documented, but this is the most accurate
    # source of information on error codes.
    ERROR_REFERENCE = "https://github.com/mongodb/mongo/blob/master/docs/errors.md"

    # Generic error class for exceptions related to connection failures.
    class ConnectionFailure < StandardError; end

    # Tag applied to unhandled exceptions on a node.
    module SocketError end

    # Generic error class for exceptions generated on the remote MongoDB
    # server.
    class MongoError < StandardError
      # @return the command that generated the error
      attr_reader :command

      # @return [Hash] the details about the error
      attr_reader :details

      # Create a new operation failure exception.
      #
      # @param command the command that generated the error
      # @param [Hash] details the details about the error
      def initialize(command, details)
        @command = command
        @details = details

        super build_message
      end

      private

      def build_message
        "The operation: #{command.inspect}\n#{error_message}"
      end

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

    # Exception class for exceptions generated as a direct result of an
    # operation, such as a failed insert or an invalid command.
    class OperationFailure < MongoError; end

    # Exception raised on invalid queries.
    class QueryFailure < MongoError; end

    # Exception raised when authentication fails.
    class AuthenticationFailure < MongoError; end

    # Raised when providing an invalid string from an object id.
    class InvalidObjectId < StandardError
      def initialize(string)
        super("'#{string}' is not a valid object id.")
      end
    end

    # @api private
    #
    # Internal exception raised by Node#ensure_primary and captured by
    # Cluster#with_primary.
    class ReplicaSetReconfigured < StandardError; end

  end
end
