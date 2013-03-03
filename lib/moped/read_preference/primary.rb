# encoding: utf-8
module Moped
  module ReadPreference
    module Primary
      extend self

      # Select a primary node from the ring. If no primary node is available
      # then an exception will be raised.
      #
      # @example Select a primary node from the ring.
      #   Moped::ReadPreference::Primary.select(ring)
      #
      # @param [ Ring ] ring The ring of nodes to select from.
      # @param [ Array<Hash> ] tags The configured tag sets.
      #
      # @raise [ Unavailable ] If no primary node was available in the ring.
      #
      # @return [ Node ] The selected primary node.
      #
      # @since 2.0.0
      def select(ring, tags = nil)
        ring.next_primary || unavailable!
      end

      private

      def unavailable!
        raise Unavailable.new("No primary node was available for selection")
      end
    end
  end
end
