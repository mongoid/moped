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

    # Get the next Node in the Ring. Will take the Node from the beginning of
    # the Node list and push it to the end.
    #
    # @example Get the next Node.
    #   ring.next
    #
    # @return [ Node ] The next Node in the Ring.
    #
    # @since 2.0.0
    def next
      nodes.push(nodes.shift).last
    end
  end
end
