# encoding: utf-8
module Moped
  module ReadPreference
    module Secondary
      extend self

      # Rules:
      #
      # Read only from secondary nodes, if no secondary is available then
      # raise an error.
      #
      # If a tag set was provided, then read from a secondary with a matching
      # tag. If none is available then raise an error.
      def select(cluster, tags = nil)
      end
    end
  end
end
