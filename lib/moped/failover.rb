# encoding: utf-8
require "moped/failover/ignore"

module Moped

  # Provides behaviour around failover scenarios for different types of
  # exceptions that get raised on connection and execution of operations.
  #
  # @since 2.0.0
  module Failover
    extend self

    # Hash lookup for the failover classes based off the exception type.
    #
    # @since 2.0.0
    STRATEGIES = {}.freeze

    # Get the appropriate failover handler given the provided exception.
    #
    # @example Get the failover handler for an IOError.
    #   Moped::Failover.get(IOError)
    #
    # @param [ Exception ] exception The raised exception.
    #
    # @return [ Object ] The failover handler.
    #
    # @since 2.0.0
    def get(exception)
      STRATEGIES.fetch(exception, Ignore).new(exception)
    end
  end
end
