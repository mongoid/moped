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
    def initialize(nodes, options = {})
      @nodes = nodes
      @options = options
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
      shuffle.find do |node|
        node.primary?
      end
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
      shuffle.find do |node|
        node.secondary?
      end
    end

    # Adds discovered peer nodes to the Ring. Will not duplicate nodes and will
    # handle nil values.
    #
    # @example Add newly discovered nodes to the Ring.
    #   ring.add(node_one, node_two)
    #
    # @param [ Array<Node> ] discovered The discovered nodes.
    #
    # @return [ Ring ] The Ring itself.
    #
    # @since 2.0.0
    def add(*discovered)
      discovered.flatten.compact.each do |node|
        nodes.push(node) unless nodes.include?(node)
      end and self
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
    def shuffle
      next_node = nodes.shift
      # @todo: Durran: Check if the node needs a refresh here, and do it at
      # this time if so. Should we also refresh others?
      nodes.push(next_node)
    end
  end
end
