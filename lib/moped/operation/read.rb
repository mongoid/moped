# encoding: utf-8
module Moped
  module Operation

    # Represents a read from the database that is executed on a specific node
    # determined by a read preference.
    #
    # @since 2.0.0
    class Read

      # @!attribute database
      #   @return [ String ] The database the read is from.
      # @!attribute operation
      #   @return [ Protocol::Query, Protocol::GetMore, Protocol::Command ]
      #     The read operation.
      attr_reader :database, :operation

      # Instantiate the read operation.
      #
      # @example Instantiate the read.
      #   Read.new(get_more)
      #
      # @param [ Protocol::Query, Protocol::GetMore, Protocol::Command ] operation
      #   The read operation.
      #
      # @since 2.0.0
      def initialize(operation)
        @operation = operation
        @database = operation.database
      end

      # Execute the read operation on the provided node. If the query failed, we
      # will check if the failure was due to authorization and attempt the
      # operation again. This could sometimes happen in the case of a step down
      # or reconfiguration on the server side.
      #
      # @example Execute the operation.
      #   read.execute(node)
      #
      # @param [ Node ] node The node to execute the read on.
      #
      # @raise [ Failure ] If the read operation failed.
      #
      # @return [ Protocol::Reply ] The reply from the database.
      #
      # @since 2.0.0
      def execute(node)
        node.process(operation) do |reply|
          if operation.failure?(reply)
            raise operation.failure_exception(reply)
          end
          operation.results(reply)
        end
      end
    end
  end
end
