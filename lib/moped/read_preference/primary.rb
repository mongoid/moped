# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a primary read preference.
    #
    # @since 2.0.0
    class Primary
      include Taggable

      # Get the name for the read preference on the server side.
      #
      # @example Get the name of the read preference.
      #   primary.name
      #
      # @return [ Symbol ] :primary.
      #
      # @since 2.0.0
      def name
        :primary
      end

      # Select a primary node from the ring. If no primary node is available
      # then an exception will be raised.
      #
      # @example Select a primary node from the ring.
      #   Moped::ReadPreference::Primary.select(ring)
      #
      # @param [ Ring ] ring The ring of nodes to select from.
      #
      # @raise [ Unavailable ] If no primary node was available in the ring.
      #
      # @return [ Node ] The selected primary node.
      #
      # @since 2.0.0
      def select(ring)
        ring.next_primary || unavailable!
      end

      private

      def unavailable!
        raise Unavailable.new("No primary node was available for selection")
      end
    end
  end
end
