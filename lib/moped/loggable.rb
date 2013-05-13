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
        Moped.logger.debug([ prefix, ops.first.log_inspect, "runtime: #{runtime}" ].join(' '))
      else
        first, *middle, last = ops
        Moped.logger.debug([ prefix, first.log_inspect ].join(' '))
        middle.each { |m| Moped.logger.debug([ indent, m.log_inspect ].join(' ')) }
        Moped.logger.debug([ indent, last.log_inspect, "runtime: #{runtime}" ].join(' '))
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
      Moped.logger.debug([ prefix, payload, "runtime: #{runtime}" ].join(' '))
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
      Moped.logger.warn([ prefix, payload, "runtime: #{runtime}" ].join(' '))
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
  end
end
