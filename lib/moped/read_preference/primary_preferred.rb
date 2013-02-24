module Moped
  module ReadPreference
    module PrimaryPreferred
      extend self

      # Rules:
      #
      # Read from the primary, unless the primary is unavailable.
      #
      # If a tag set is provided, read from seondaries that match the tag.
      # If none match, raise an error.
      #
      # If no tag set is provided, read from any available secondary.
      def select(cluster, tags = nil)

      end
    end
  end
end
