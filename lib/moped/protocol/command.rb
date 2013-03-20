module Moped
  module Protocol

    # This is a convenience class on top of +Query+ for quickly creating a
    # command.
    #
    # @example
    #   command = Moped::Protocol::Command.new :moped, ismaster: 1
    #   socket.write command.serialize
    #
    # @since 1.0.0
    class Command < Query

      # Determine if the provided reply message is a failure with respect to a
      # command.
      #
      # @example Is the reply a command failure?
      #   command.failure?(reply)
      #
      # @param [ Reply ] reply The reply to the command.
      #
      # @return [ true, false ] If the reply is a failure.
      #
      # @since 2.0.0
      def failure?(reply)
        reply.command_failure?
      end

      # Get the exception specific to a failure of this particular operation.
      #
      # @example Get the failure exception.
      #   command.failure_exception(document)
      #
      # @param [ Moped::Protocol::Reply ] reply The reply from the database.
      #
      # @return [ Moped::Errors::OperationFailure ] The failure exception.
      #
      # @since 2.0.0
      def failure_exception(reply)
        Errors::OperationFailure.new(self, reply.documents.first)
      end

      # Instantiate the new command.
      #
      # @example Instantiate the new command.
      #   Moped::Protocol::Command.new(:moped_test, ismaster: 1)
      #
      # @param [ String, Symbol ] database The database to run the command on.
      # @param [ Hash ] command The command to run.
      # @param [ Hash ] options And additional query options.
      #
      # @since 1.0.0
      def initialize(database, command, options = {})
        super(database, '$cmd', command, options.merge(limit: -1))
      end

      # Provide the value that will be logged when the command runs.
      #
      # @example Provide the log inspection.
      #   command.log_inspect
      #
      # @return [ String ] The string value for logging.
      #
      # @since 1.0.0
      def log_inspect
        type = "COMMAND"
        "%-12s database=%s command=%s" % [type, database, selector.inspect]
      end

      # Take the provided reply and return the expected results to api
      # consumers. In the case of the command it's the first document.
      #
      # @example Get the expected results of the reply.
      #   command.results(reply)
      #
      # @param [ Moped::Protocol::Reply ] reply The reply from the database.
      #
      # @return [ Hash ] The first document in the reply.
      #
      # @since 2.0.0
      def results(reply)
        reply.documents.first
      end
    end
  end
end
