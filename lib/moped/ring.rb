# encoding: utf-8
module Moped

  # Represents a ring of nodes in order to iterate through nodes in a round
  # robin fashion for even distribution of operations.
  #
  # @since 2.0.0
  class Ring

    # @!attribute nodes
    #   @return [ Array<Node> ] The Nodes in the Ring.
    attr_reader :nodes

    # Initialize the new Ring.
    #
    # @example Initialize the Ring.
    #   Moped::Ring.new([ node_one, node_two ])
    #
    # @param [ Array<Node> ] nodes The Nodes.
    #
    # @since 2.0.0
    def initialize(nodes)
      @nodes = nodes
    end

    # Get the next primary Node in the Ring. Will take the Node from the
    # beginning of the Node list and push it to the end.
    #
    # @example Get the next primary Node.
    #   ring.next_primary
    #
    # @return [ Node ] The next primary Node in the Ring.
    #
    # @since 2.0.0
    def next_primary
      (node = next_node).primary? ? node : next_primary
    end

    # Get the next secondary Node in the Ring. Will take the Node from the
    # beginning of the Node list and push it to the end.
    #
    # @example Get the next secondary Node.
    #   ring.next_secondary
    #
    # @return [ Node ] The next secondary Node in the Ring.
    #
    # @since 2.0.0
    def next_secondary
      (node = next_node).secondary? ? node : next_secondary
    end

    private

    # Get the next node of any type in the ring and shift the nodes.
    #
    # @api private
    #
    # @example Get the next node in the Ring.
    #   ring.next_node
    #
    # @return [ Node ] The next node in the Ring.
    #
    # @since 2.0.0
    def next_node
      nodes.push(nodes.shift).last
    end
  end
end
