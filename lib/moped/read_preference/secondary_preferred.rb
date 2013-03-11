# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a secondary read preference.
    #
    # @since 2.0.0
    class SecondaryPreferred
      include Taggable

      # Select a secondary node from the ring. If no secondary is available then
      # use a primary. If no primary is found then an exception will be raised.
      #
      # @example Read a secondary or primary node from the ring.
      #   Moped::ReadPreference::SecondaryPreferred.select(ring)
      #
      # @note If tag sets are provided then secondary selection will need to
      #   match the provided tags.
      #
      # @param [ Ring ] ring The ring of nodes to select from.
      #
      # @raise [ Unavailable ] If no secondary or primary node was available in
      #   the ring.
      #
      # @return [ Node ] The selected node.
      #
      # @since 2.0.0
      def select(ring)
        ring.next_secondary || ring.next_primary || unavailable!
      end

      private

      def unavailable!
        raise Unavailable.new("No secondary or primary node is available for selection.")
      end
    end
  end
end
