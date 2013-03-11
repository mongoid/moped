# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a primary preferred read preference.
    #
    # @since 2.0.0
    class PrimaryPreferred
      include Taggable

      # Select a primary node from the ring. If no primary node is available
      # then attempt to select a secondary. If no secondary is available then
      # an exception will be raised.
      #
      # @example Prefer to select a primary node from the ring.
      #   Moped::ReadPreference::PrimaryPreferred.select(ring)
      #
      # @note If tag sets are provided then secondary selection will need to
      #   match the provided tags.
      #
      # @param [ Ring ] ring The ring of nodes to select from.
      #
      # @raise [ Unavailable ] If no primary or secondary node was available in the ring.
      #
      # @return [ Node ] The selected node.
      #
      # @since 2.0.0
      def select(ring)
        ring.next_primary || ring.next_secondary || unavailable!
      end

      private

      def unavailable!
        raise Unavailable.new("No primary or secondary node was available for selection")
      end
    end
  end
end
