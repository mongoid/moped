# encoding: utf-8
module Moped

  # Represents a ring of nodes in order to iterate through nodes in a round
  # robin fashion for even distribution of operations.
  #
  # @since 2.0.0
  class Ring

    # The default interval that a node would be flagged as "down".
    #
    # @since 2.0.0
    DOWN_INTERVAL = 30

    # The default interval that a node should be refreshed in.
    #
    # @since 2.0.0
    REFRESH_INTERVAL = 300

    # @!attribute nodes
    #   @return [ Array<Node> ] The Nodes in the Ring.
    # @!attribute options
    #   @return [ Hash ] The refresh options.
    attr_reader :nodes, :options

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

    # Get the interval at which a node should be flagged as down before
    # retrying.
    #
    # @example Get the down interval, in seconds.
    #   ring.down_interval
    #
    # @return [ Integer ] The down interval.
    #
    # @since 2.0.0
    def down_interval
      @down_interval ||= options[:down_interval] || DOWN_INTERVAL
    end

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
      shift.find do |node|
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
      shift.find do |node|
        node.secondary?
      end
    end

    # Get the interval in which the node list should be refreshed.
    #
    # @example Get the refresh interval, in seconds.
    #   ring.refresh_interval
    #
    # @return [ Integer ] The refresh interval.
    #
    # @since 2.0.0
    def refresh_interval
      @refresh_interval ||= options[:refresh_interval] || REFRESH_INTERVAL
    end

    private

    # Get the boundary where a node that is down would need to be refreshed.
    #
    # @api private
    #
    # @example Get the down boundary.
    #   ring.down_boundary
    #
    # @return [ Time ] The down boundary.
    #
    # @since 2.0.0
    def down_boundary
      Time.new - down_interval
    end

    # Get the standard refresh boundary to discover new nodes.
    #
    # @api private
    #
    # @example Get the refresh boundary.
    #   ring.refresh_boundary
    #
    # @return [ Time ] The refresh boundary.
    #
    # @since 2.0.0
    def refresh_boundary
      Time.new - refresh_interval
    end

    # Is the provided node refreshable? This is in the case where the refresh
    # boundary has passed, or the node has been down longer than the down
    # boundary.
    #
    # @api private
    #
    # @example Is the node refreshable?
    #   ring.refreshable?(node)
    #
    # @param [ Node ] node The Node to check.
    #
    # @since 2.0.0
    def refreshable?(node)
      node.down? ? node.down_at < down_boundary : node.needs_refresh?(refresh_boundary)
    end

    # Get the next node of any type in the ring and shift the nodes. If the
    # node is down or needs a refresh we will do it now. If the node is still
    # down after refresh we will shift the nodes again.
    #
    # @api private
    #
    # @example Get the next node in the Ring.
    #   ring.next_node
    #
    # @return [ Node ] The next node in the Ring.
    #
    # @since 2.0.0
    def shift
      if nodes.empty?
        nodes
      else
        nodes.push(nodes.shift)
      end
    end
  end
end
