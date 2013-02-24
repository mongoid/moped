module Moped
  module ReadPreference
    module Nearest
      extend self

      # Rules:
      #
      # Read from the nearest member in the set, based on ping time (primary
      # or secondary is allowed.
      #
      # If a tag set is provided, then read from the closest matching, raising
      # an error if none match.
      def select(cluster, tags = nil)

      end
    end
  end
end
