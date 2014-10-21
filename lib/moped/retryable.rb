# encoding: utf-8
module Moped
  # Provides the shared behaviour for retry failed operations.
  #
  # @since 2.0.0
  module Retryable

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
      rescue Errors::ConnectionFailure, Errors::PotentialReconfiguration => e
        raise e if e.is_a?(Errors::PotentialReconfiguration) &&
          ! (e.message.include?("not master") || e.message.include?("Not primary"))

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
