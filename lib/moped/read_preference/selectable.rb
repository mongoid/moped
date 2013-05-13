# encoding: utf-8
module Moped
  module ReadPreference

    # Provides the shared behaviour for read preferences that can filter by a
    # tag set or add query options.
    #
    # @since 2.0.0
    module Selectable

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

      private

      # Execute the provided block on the cluster and retry if the execution
      # fails.
      #
      # @api private
      #
      # @example Execute with retry.
      #   preference.with_retry(cluster) do
      #     cluster.with_primary do |node|
      #       node.refresh
      #     end
      #   end
      #
      # @param [ Cluster ] cluster The cluster.
      # @param [ Integer ] retries The number of times to retry.
      #
      # @return [ Object ] The result of the block.
      #
      # @since 2.0.0
      def with_retry(cluster, retries = cluster.max_retries, &block)
        begin
          block.call
        rescue Errors::ConnectionFailure => e
          if retries > 0
            Loggable.warn("  MOPED:", "Retrying connection attempt #{retries} more time(s).", "n/a")
            sleep(cluster.retry_interval)
            cluster.refresh
            with_retry(cluster, retries - 1, &block)
          else
            raise e
          end
        end
      end
    end
  end
end
