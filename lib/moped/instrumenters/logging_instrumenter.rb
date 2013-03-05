# encoding: utf-8
module Moped
  module Instrumenters

    # Provides logging instrumentation for compatibility with active support
    # notifications.
    #
    # @since 2.0.0
    class LoggingInstrumenter

      # The name of the channel of operations for Moped.
      #
      # @since 2.0.0
      CHANNEL = "moped.operations"

      # Instrument the log payload.
      #
      # @example Instrument the log payload.
      #   LoggingInstrumentor.instrument("moped.ops", {})
      #
      # @param [ String ] name The name of the logging type.
      # @param [ Hash ] payload The log payload.
      #
      # @since 2.0.0
      def self.instrument(name, payload = {})
        started = Time.new
        begin
          yield if block_given?
        rescue Exception => e
          payload[:exception] = [ e.class.name, e.message ]
          raise e
        ensure
          runtime = ("%.4fms" % (1000 * (Time.now.to_f - started.to_f)))
          if name == CHANNEL
            Moped::Logging.log_operations(payload[:prefix], payload[:ops], runtime)
          else
            Moped::Logging.debug(payload[:prefix], payload.reject { |k,v| k == :prefix }, runtime)
          end
        end
      end
    end
  end
end
