# encoding: utf-8
module Moped
  module Operation

    class Write

      # The operation can be a Protocol::Insert, Protocol::Update,
      # Protocol::Delete
      def initialize(operation)
        @operation = operation
      end

      def execute(node)
        # node.process(operation)
        # Check our write concern and then do the right thing.
      end
    end
  end
end
