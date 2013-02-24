module Moped
  module ReadPreference
    module SecondaryPreferred
      extend self

      # Rules:
      #
      # Attempt to read from a secondary node. If none is available then read
      # from the primary.
      #
      # If a tag set was included, then attempt to read from a secondary node
      # with a matching tag. If none is found raise an error.
      def select(cluster, tags = nil)

      end
    end
  end
end
