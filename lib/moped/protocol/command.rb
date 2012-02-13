module Moped
  module Protocol

    # This is a convenience class on top of +Query+ for quickly creating a
    # command.
    #
    # @example
    #   command = Moped::Protocol::Command.new :moped, ismaster: 1
    #   socket.write command.serialize
    class Command < Query

      # @param [String, Symbol] database the database to run this command on
      # @param [Hash] command the command to run
      def initialize(database, command)
        super database, :$cmd, command, limit: -1
      end

      def log_inspect
        type = "COMMAND"

        "%-12s database=%s command=%s" % [type, database, selector.inspect]
      end

    end

  end
end
