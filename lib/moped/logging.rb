module Moped

  # Contains behaviour for logging.
  module Logging

    def self.log_operations(prefix, ops, runtime)
      indent  = " "*prefix.length

      if ops.length == 1
        Moped.logger.debug [prefix, ops.first.log_inspect, "runtime: #{runtime}"].join(' ')

      else
        first, *middle, last = ops

        Moped.logger.debug [prefix, first.log_inspect].join(' ')
        middle.each { |m| Moped.logger.debug [indent, m.log_inspect].join(' ') }
        Moped.logger.debug [indent, last.log_inspect, "runtime: #{runtime}"].join(' ')

      end
    end

    def self.debug(prefix, payload, runtime)
      Moped.logger.debug [prefix, payload, "runtime: #{runtime}"].join(' ')
    end

    # Get the logger.
    #
    # @example Get the logger.
    #   Logging.logger
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
    #   Logging.rails_logger
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
    #   Logging.default_logger
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
    #   Logging.logger = logger
    #
    # @return [ Logger ] The logger.
    #
    # @since 1.0.0
    def logger=(logger)
      @logger = logger
    end
  end
  extend Logging
end
