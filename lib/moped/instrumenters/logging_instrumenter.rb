module Moped
  module Instrumenters
    class LoggingInstrumenter

      def self.instrument(name, payload = {})
        started = Time.new
        begin
          yield if block_given?
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          raise e
        ensure
          runtime = 1000 * Time.now.to_f - started.to_f
          if name == 'moped.operations'
            Moped::Logging.log_operations(payload[:prefix], payload[:ops], runtime)
          else
            Moped::Logging.debug(payload[:prefix], payload.reject { |k,v| k == :prefix }, runtime)
          end
        end
      end
    end
  end
end
