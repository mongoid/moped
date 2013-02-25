# encoding: utf-8
module Moped

  class Write

    # The operation can be a Protocol::Insert, Protocol::Update,
    # Protocol::Delete, Protocol::Command.
    def initialize(operation)
      @operation = operation
    end

    def execute(node)
      reply = node.process(operation)
      # @todo: Durran check the reply for failover situations and handle them
      # here.
      reply
    end
  end
end
