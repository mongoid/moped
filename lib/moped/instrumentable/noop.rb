# encoding: utf-8
module Moped
  module Instrumentable

    # Does not instrument anything, just yields.
    #
    # @since 2.0.0
    class Noop

      class << self

        # Do not instrument anything.
        #
        # @example Do not instrument.
        #   Noop.instrument("moped.noop") do
        #     node.connect
        #   end
        #
        # @param [ String ] name The name of the operation.
        # @param [ Hash ] payload The payload.
        #
        # @return [ Object ] The result of the yield.
        #
        # @since 2.0.0
        def instrument(name, payload = {})
          yield payload if block_given?
        end
      end
    end
  end
end
