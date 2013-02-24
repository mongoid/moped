module Moped
  module ReadPreference
    module Primary
      extend self

      # Rules:
      #
      # If No primary available then raise error. This is default.
      def select(cluster, tags = nil)

      end
    end
  end
end
