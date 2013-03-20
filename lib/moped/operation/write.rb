# encoding: utf-8
module Moped
  module Operation

    # Encapsulates behaviour for write operations.
    #
    # @since 2.0.0
    class Write

      # @!attribute concern
      #   @return [ Object ] The configured write concern.
      # @!attribute database
      #   @return [ String ] The database the read is from.
      # @!attribute operation
      #   @return [ Protocol::Insert, Protocol::Update, Protocol::Delete ]
      #     The write operation.
      attr_reader :concern, :database, :operation

      # Instantiate the write operation.
      #
      # @example Instantiate the write.
      #   Write.new(insert)
      #
      # @param [ Protocol::Insert, Protocol::Update, Protocol::Delete ] operation
      #   The write operation.
      #
      # @since 2.0.0
      def initialize(operation, concern)
        @operation = operation
        @database = operation.database
        @concern = concern
      end

      # Execute the write operation on the provided node. If the write concern
      # is propagating, then the gle command will be piggybacked onto the
      # initial write operation.
      #
      # @example Execute the operation.
      #   write.execute(node)
      #
      # @param [ Node ] node The node to execute the write on.
      #
      # @since 2.0.0
      def execute(node)
        propagate = concern.operation
        if propagate
          node.pipeline do
            node.process(operation)
            node.command(database, propagate)
          end
        else
          node.process(operation)
        end
      end
    end
  end
end
