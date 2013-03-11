# encoding: utf-8
module Moped
  module Operation

    class Write

      # The operation can be a Protocol::Insert, Protocol::Update,
      # Protocol::Delete
      def initialize(operation, write_concern)
        @operation = operation
        @database = operation.database
        @write_concern = write_concern
      end

      def execute(node)
        message = operation.piggyback(write_concern.command(database))
        node.process(message)
      end
    end
  end
end
