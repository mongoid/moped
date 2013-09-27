# encoding: utf-8
require "moped/instrumentable/log"
require "moped/instrumentable/noop"

module Moped
  module Instrumentable

    # The name of the topic of operations for Moped.
    #
    # @since 2.0.0
    TOPIC = "query.moped"

    # @!attribute instrumenter
    #   @return [ Object ] The instrumenter
    attr_reader :instrumenter

    # Instrument and execute the provided block.
    #
    # @example Instrument and execute.
    #   instrument("moped.noop") do
    #     node.connect
    #   end
    #
    # @param [ String ] name The name of the operation.
    # @param [ Hash ] payload The payload.
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 2.0.0
    def instrument(name, payload = {}, &block)
      instrumenter.instrument(name, payload, &block)
    end
  end
end
