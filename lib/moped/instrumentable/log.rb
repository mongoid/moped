# encoding: utf-8
module Moped
  module Instrumentable

    # Provides logging instrumentation for compatibility with active support
    # notifications.
    #
    # @since 2.0.0
    module Log
      extend self

      # Instrument the log payload.
      #
      # @example Instrument the log payload.
      #   Log.instrument("moped.ops", {})
      #
      # @param [ String ] name The name of the logging type.
      # @param [ Hash ] payload The log payload.
      #
      # @return [ Object ] The result of the yield.
      #
      # @since 2.0.0
      def instrument(name, payload = {})
        started = Time.new
        begin
          yield if block_given?
        rescue Exception => e
          payload[:exception] = [ e.class.name, e.message ]
          raise e
        ensure
          runtime = ("%.4fms" % (1000 * (Time.now.to_f - started.to_f)))
          Moped::Loggable.log_operations(payload[:prefix], payload[:ops], runtime)
        end
      end
    end
  end
end
