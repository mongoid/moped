# encoding: utf-8
module Moped
  module ReadPreference

    # Encapsulates behaviour around a nearest read preference.
    #
    # @since 2.0.0
    class Nearest
      include Taggable

      # Rules:
      #
      # Read from the nearest member in the set, based on ping time (primary
      # or secondary is allowed.)
      #
      # If a tag set is provided, then read from the closest matching, raising
      # an error if none match.
      def select(ring)

      end
    end
  end
end
