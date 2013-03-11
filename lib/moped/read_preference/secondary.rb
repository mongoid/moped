# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a secondary read preference.
    #
    # @since 2.0.0
    class Secondary
      include Taggable

      # Select a secondary node from the ring. If no secondary is available then
      # an exception will be raised.
      #
      # @example Read a secondary node from the ring.
      #   Moped::ReadPreference::Secondary.select(ring)
      #
      # @note If tag sets are provided then secondary selection will need to
      #   match the provided tags.
      #
      # @param [ Ring ] ring The ring of nodes to select from.
      #
      # @raise [ Unavailable ] If no secondary node was available in the ring.
      #
      # @return [ Node ] The selected node.
      #
      # @since 2.0.0
      def select(ring)
        ring.next_secondary || unavailable!
      end

      private

      def unavailable!
        raise Unavailable.new("No secondary node was available for selection.")
      end
    end
  end
end
