module Moped
  module Logging
    def logger
      return @logger if defined?(@logger)

      @logger = rails_logger || default_logger
    end

    def rails_logger
      defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    end

    def default_logger
      Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::INFO
      end
    end

    def logger=(logger)
      @logger = logger
    end
  end

  extend Logging
end
