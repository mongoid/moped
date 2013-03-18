# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a nearest read preference.
    #
    # @since 2.0.0
    class Nearest
      include Selectable

      # Get the name for the read preference on the server side.
      #
      # @example Get the name of the read preference.
      #   nearest.name
      #
      # @return [ Symbol ] :nearest.
      #
      # @since 2.0.0
      def name
        :nearest
      end

      # Rules:
      #
      # Read from the nearest member in the set, based on ping time (primary
      # or secondary is allowed.)
      #
      # If a tag set is provided, then read from the closest matching, raising
      # an error if none match.
      def with_node(cluster, &block)

      end
    end
  end
end
