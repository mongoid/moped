# encoding: utf-8

module Moped

  # The class for interacting with a MongoDB database. One only interacts with
  # this class indirectly through a session.
  #
  # @example
  #   session.use :moped
  #   session.drop
  #   session[:users].insert(name: "John")
  #
  # @example
  #   session.with(database: :moped) do |moped|
  #     moped[:users].drop
  #   end
  class Database

    # @return [Session] the database's session
    attr_reader :session

    # @return [String, Symbol] the database's name
    attr_reader :name

    # @param [Session] session the session
    # @param [String, Symbol] name the database's name
    def initialize(session, name)
      @session = session
      @name = name
    end

    # Drop the database.
    def drop
      session.with(consistency: :strong) do |session|
        session.context.command name, dropDatabase: 1
      end
    end

    # Log in with +username+ and +password+ on the current database.
    #
    # @param [String] username the username
    # @param [String] password the password
    def login(username, password)
      session.context.login(name, username, password)
    end

    # Log out from the current database.
    def logout
      session.context.logout(name)
    end

    # Run +command+ on the database.
    #
    # @example
    #   db.command(ismaster: 1)
    #   # => { "master" => true, hosts: [] }
    #
    # @param [Hash] command the command to run
    # @return [Hash] the result of the command
    def command(command)
      session.context.command name, command
    end

    # @param [Symbol, String] collection the collection name
    # @return [Moped::Collection] an instance of +collection+
    def [](collection)
      Collection.new(self, collection)
    end
  end
end
