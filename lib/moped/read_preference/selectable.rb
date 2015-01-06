# encoding: utf-8
require "moped/retryable"
module Moped
  module ReadPreference

    # Provides the shared behaviour for read preferences that can filter by a
    # tag set or add query options.
    #
    # @since 2.0.0
    module Selectable
      include Retryable

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

      # Get the provided options as query options for this read preference.
      #
      # @example Get the query options.
      #   preference.query_options({})
      #
      # @param [ Hash ] options The existing options for the query.
      #
      # @return [ Hash ] The options plus additional query options.
      #
      # @since 2.0.0
      def query_options(options)
        options[:flags] ||= []
        options[:flags] |= [ :slave_ok ]
        options
      end
    end
  end
end
