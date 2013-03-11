# encoding: utf-8
module Moped
  module ReadPreference

    # Provides the shared behaviour for read preferences that can filter by a
    # tag set.
    #
    # @since 2.0.0
    module Taggable

      # @!attribute tags
      #   @return [ Array<Hash> ] The tag sets.
      attr_reader :tags

      # Instantiate the new taggable read preference.
      #
      # @example Instantiate the taggable.
      #   Moped::ReadPreference::Secondary.new({ east_coast: 1 })
      #
      # @param [ Array<Hash> ] tags The tag sets.
      #
      # @since 2.0.0
      def initialize(tags = nil)
        @tags = tags
      end
    end
  end
end
