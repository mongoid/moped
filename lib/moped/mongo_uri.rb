# encoding: utf-8
module Moped

  # Parses MongoDB uri
  #
  # @api public
  class MongoUri

    SCHEME = /(mongodb:\/\/)/
    USER = /([-.\w:]+)/
    PASS = /([^@,]+)/
    NODES = /((([-.\w]+)(?::(\w+))?,?)+)/
    DATABASE = /(?:\/([-\w]+))?/
    OPTIONS  = /(?:\?(.+))/

    URI = /#{SCHEME}(#{USER}:#{PASS}@)?#{NODES}#{DATABASE}#{OPTIONS}?/

    attr_reader :match

    # Helper to determine if authentication is provided
    #
    # @example Boolean response if username/password given
    #   uri.auth_provided?
    #
    # @return [ true, false ] If authorization is provided.
    #
    # @since 1.3.0
    def auth_provided?
      !username.nil? && !password.nil?
    end

    # Get the database provided in the URI.
    #
    # @example Get the database.
    #   uri.database
    #
    # @return [ String ] The database.
    #
    # @since 1.3.0
    def database
      @database ||= match[9]
    end

    # Get the hosts provided in the URI.
    #
    # @example Get the hosts.
    #   uri.hosts
    #
    # @return [ Array<String> ] The hosts.
    #
    # @since 1.3.0
    def hosts
      @hosts ||= match[5].split(",")
    end

    # Create the new uri from the provided string.
    #
    # @example Create the new uri.
    #   MongoUri.new(uri)
    #
    # @param [ String ] string The uri string.
    #
    # @since 1.3.0
    def initialize(string)
      @match = string.match(URI)
      invalid_uri!(string) unless @match
    end

    # Raise a human readable error when improper URI provided
    #
    # @example Raise error and provide guidance on invalid URI
    #   MongoUri.invalid!(uri)
    #
    # @param [ String ] Invalid string
    #
    # @since 1.3.1
    def invalid_uri!(string)
      msg = %{
The given connection string is invalid:
  #{string.gsub(/[^:]+@/, '<password>@')}

MongoDB connection strings must be of the format:
  mongodb://host:port/database

For authentication, include username and password before host:
  mongodb://username:password@host:port/database

For Replica Sets, include multiple host:port entries:
  mongodb://host:port,host2:port2/database

For options, use query string syntax with the option value:
  mongodb://host:port/database?safe=true&max_retries=30&timeout=5
      }
      raise Errors::InvalidMongoURI, msg
    end

    # Get the options provided in the URI.
    # @example Get the options
    #   uri.options
    #
    # @return [ Hash ] Options hash usable by Moped
    #
    # @since 1.3.0
    def options
      options_string, options = @match[10], {database: database}

      unless options_string.nil?
        options_string.split(/\&/).each do |option_string|
          key, value = option_string.split(/=/)

          if value == "true"
            options[key.to_sym] = true
          elsif value == "false"
            options[key.to_sym] = false
          elsif value =~ /[\d]/
            options[key.to_sym] = value.to_i
          else
            options[key.to_sym] = value.to_sym
          end
        end
      end

      options
    end

    # Get the password provided in the URI.
    #
    # @example Get the password.
    #   uri.password
    #
    # @return [ String ] The password.
    #
    # @since 1.3.0
    def password
      @password ||= match[4]
    end

    # Get the uri as a Mongoid friendly configuration hash.
    #
    # @example Get the uri as a hash.
    #   uri.to_hash
    #
    # @return [ Hash ] The uri as options.
    #
    # @since 1.3.0
    def to_hash
      config = { database: database, hosts: hosts }
      if username && password
        config.merge!(username: username, password: password)
      end
      config
    end

    # Create Moped usable arguments
    #
    # @example Get the moped args
    #   uri.moped_arguments
    #
    # @return [ Array ] Array of arguments usable by Moped
    #
    # @since 1.3.0
    def moped_arguments
      [hosts, options]
    end

    # Get the username provided in the URI.
    #
    # @example Get the username.
    #   uri.username
    #
    # @return [ String ] The username.
    #
    # @since 1.3.0
    def username
      @username ||= match[3]
    end
  end
end
