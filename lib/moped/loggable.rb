require "moped/log_format/default_format"
require "moped/log_format/shell_format"

# encoding: utf-8
module Moped

  # Contains behaviour for logging.
  #
  # @since 1.0.0
  module Loggable

    # Log the provided operations.
    #
    # @example Log the operations.
    #   Loggable.log_operations("MOPED", {}, 30)
    #
    # @param [ String ] prefix The prefix for all operations in the log.
    # @param [ Array ] ops The operations.
    # @param [ String ] runtime The runtime in formatted ms.
    #
    # @since 2.0.0
    def self.log_operations(prefix, ops, runtime)
      indent  = " "*prefix.length
      if ops.length == 1
        Moped.logger.debug(Moped.log_format.log(prefix, ops.first.log_inspect, runtime))
      else
        first, *middle, last = ops
        Moped.logger.debug(Moped.log_format.log(prefix, first.log_inspect))
        middle.each { |m| Moped.logger.debug(Moped.log_format.log(indent, m.log_inspect)) }
        Moped.logger.debug(Moped.log_format.log(indent, last.log_inspect, runtime))
      end
    end

    # Log the payload to debug.
    #
    # @example Log to debug.
    #   Loggable.debug("MOPED", payload "30.012ms")
    #
    # @param [ String ] prefix The log prefix.
    # @param [ String ] payload The log operations.
    # @param [ String ] runtime The runtime in formatted ms.
    #
    # @since 2.0.0
    def self.debug(prefix, payload, runtime)
      Moped.logger.debug(Moped.log_format.log(prefix, payload, runtime))
    end

    # Log the payload to warn.
    #
    # @example Log to warn.
    #   Loggable.warn("MOPED", payload "30.012ms")
    #
    # @param [ String ] prefix The log prefix.
    # @param [ String ] payload The log operations.
    # @param [ String ] runtime The runtime in formatted ms.
    #
    # @since 2.0.0
    def self.warn(prefix, payload, runtime)
      Moped.logger.warn(Moped.log_format.log(prefix, payload, runtime))
    end

    # Get the logger.
    #
    # @example Get the logger.
    #   Loggable.logger
    #
    # @return [ Logger ] The logger.
    #
    # @since 1.0.0
    def logger
      return @logger if defined?(@logger)
      @logger = rails_logger || default_logger
    end

    # Get the rails logger.
    #
    # @example Get the rails logger.
    #   Loggable.rails_logger
    #
    # @return [ Logger ] The Rails logger.
    #
    # @since 1.0.0
    def rails_logger
      defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    end

    # Get the default logger.
    #
    # @example Get the default logger.
    #   Loggable.default_logger
    #
    # @return [ Logger ] The default logger.
    #
    # @since 1.0.0
    def default_logger
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger
    end

    # Set the logger.
    #
    # @example Set the logger.
    #   Loggable.logger = logger
    #
    # @return [ Logger ] The logger.
    #
    # @since 1.0.0
    def logger=(logger)
      @logger = logger
    end

    # Get the log format.
    #
    # @example Get the log format.
    #   Loggable.logger
    #
    # @return [ Logger ] The log format.
    #
    # @since 2.0.0
    def log_format
      return @log_format if defined?(@log_format)
      @log_format = Moped::LogFormat::DefaultFormat
    end

    # Set the log formatt.
    #
    # @example Set the log formatt.
    #   Loggable.log_format = format
    #
    # @return [ LogFormat ] The log format.
    #
    # @since 2.0.0
    def log_format=(format)
      @log_format = format
    end
  end
end