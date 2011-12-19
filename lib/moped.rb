require "crutches/bson"
require "crutches/protocol"
require "monitor"
require "forwardable"

module Moped
  BSON = Crutches::BSON
  Protocol = Crutches::Protocol

  class Protocol::Query
    attr_accessor :callback
  end

  class Session
    extend Forwardable

    # @return [Hash] this session's options
    attr_reader :options

    # @return [Cluster] this session's cluster
    attr_reader :cluster

    # @param [String] seeds a comma separated list of host:port pairs
    # @param [Hash] options
    # @option options [Boolean] :safe (false) ensure writes are persisted
    # @option options [Hash] :safe ensure writes are persisted with the
    #   specified safety level e.g., "fsync: true", or "w: 2, wtimeout: 5"
    # @option options [Symbol, String] :database the database to use
    def initialize(seeds, options = {})
      @cluster = Cluster.new(seeds)
      @options = options
    end

    # @return [Boolean] whether the current session requires safe operations.
    def safe?
      !!safety
    end

    # @return [Boolean, Hash] the safety level for this session
    def safety
      options[:safe]
    end

    # Switch the session's current database.
    #
    # @example
    #   session.use :moped
    #   session[:people].find.one # => { :name => "John" }
    #
    # @param [String] database the database to use
    def use(database)
      options[:database] = database
      set_current_database database
    end

    # Create a new session with +options+ reusing existing connections.
    #
    # @example Change safe mode
    #   session.with(safe: { w: 2 })[:people].insert(name: "Joe")
    #
    # @example Change safe mode with block
    #   session.with(safe: { w: 2 }) do |session|
    #     session[:people].insert(name: "Joe")
    #   end
    #
    # @example Temporarily change database
    #   session.with(database: "admin") do |admin|
    #     admin.command ismaster: 1
    #   end
    #
    # @example Copy between databases
    #   session.use "moped"
    #   session.with(database: "backup") do |backup|
    #     session[:people].each do |person|
    #       backup[:people].insert person
    #     end
    #   end
    #
    # @yieldparam [Moped::Session] session the new session
    # @return [Moped::Session] the new session
    def with(options = {})
      session = dup
      session.options.update options

      yield session if block_given?
      session
    end

    # Create a new session with +options+ and use new socket connections.
    #
    # @see #with
    # @yieldparam [Moped::Session] session the new session
    # @return [Moped::Session] the new session
    def new(options = {})
    end

    # @method [](collection)
    # Return +collection+ from the current database.
    #
    # @param (see Moped::Database#[])
    # @return (see Moped::Database#[])
    delegate :"[]" => :current_database

    # @method command(command)
    # Run +command+ on the current database.
    #
    # @param (see Moped::Database#command)
    # @return (see Moped::Database#command)
    delegate :command => :current_database

    # @method drop
    # Drop the current database.
    #
    # @param (see Moped::Database#drop)
    # @return (see Moped::Database#drop)
    delegate :drop => :current_database

    # @api private
    delegate :socket_for => :cluster

    def current_database
      return @current_database if defined? @current_database

      if database = options[:database]
        set_current_database(database)
      else
        raise "No database set for session. Call #use or #with before accessing the database"
      end
    end

    private

    def set_current_database(database)
      @current_database = Database.new(self, database)
    end

    def dup
      session = super
      session.instance_variable_set :@options, options.dup
      session
    end
  end

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
      command dropDatabase: 1
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
      socket = session.socket_for(:write)

      socket.simple_query Protocol::Command.new(name, command)
    end

    # @param [Symbol, String] collection the collection name
    # @return [Moped::Collection] an instance of +collection+
    def [](collection)
      Collection.new(self, collection)
    end
  end

  class Collection

    # @return [Database] the database this collection belongs to
    attr_reader :database

    # @return [String, Symbol] the collection's name
    attr_reader :name

    # @param [Database] database the database this collection belongs to
    # @param [String, Symbol] name the collection's name
    def initialize(database, name)
      @database = database
      @name     = name
    end

    # Drop the collection.
    def drop
      database.command drop: name
    end

    # Build query for this collection.
    #
    # @param [Hash] query the query
    # @return [Moped::Query]
    def find(query) end
    alias where find

    # Insert one or more documents into the collection.
    #
    # @overload insert(document)
    #   @example
    #     db[:people].insert(name: "John")
    #   @param [Hash] document the document to insert
    #
    # @overload insert(documents)
    #   @example
    #     db[:people].insert([{name: "John"}, {name: "Joe"}])
    #   @param [Array<Hash>] documents the documents to insert
    def insert(documents)
      documents = [documents] unless documents.is_a? Array

      session = database.session
      socket = session.socket_for(:write)

      insert = Protocol::Insert.new(database.name, name, documents)

      if session.safe?
        last_error = Protocol::Command.new(
          database.name, getlasterror: 1, safe: session.safety
        )

        socket.execute insert
        socket.simple_query last_error
      else
        socket.execute insert
      end
    end
  end

  # The +Query+ class encapsulates all of the logic related to building
  # selectors for querying, updating, or removing documents in a collection.
  #
  # @example
  #   people = db[:people]
  #   people.find.entries # => [{id: 1}, {id: 2}, {id: 3}, {id: 4}, {id: 5}]
  #   people.find.skip(2).first # => { id: 3 }
  #   people.find.skip(2).update(name: "John")
  #   people.find.skip(2).first # => { id: 3, name: "John" }
  #
  #   people.find(name: nil).update_all(name: "Unknown")
  #   people.find.one # => { id: 5, name: "Unknown" }
  #   people.find.first # => { id: 5, name: "Unknown" }
  #   people.find.select(name: 0).first # => { id: 5 }
  #   people.find(name: "Unknown").remove_all
  #   people.find.count # => 1
  class Query
    include Enumerable

    # Set the query's limit.
    #
    # @param [Numeric] limit
    # @return [Query] self
    def limit(limit) end

    # Set the number of documents to skip.
    #
    # @param [Numeric] skip
    # @return [Query] self
    def skip(skip) end

    # Set the sort order for the query.
    #
    # @example
    #   db[:people].find.sort(name: 1, age: -1).one
    #
    # @param [Hash] sort
    # @return [Query] self
    def sort(sort) end

    # Set the fields to return from the query.
    #
    # @example
    #   db[:people].find.select(name: 1).one # => { name: "John" }
    #
    # @param [Hash] select
    # @return [Query] self
    def select(select) end

    # @return [Hash] the first document that matches the selector.
    def one() end
    alias first one

    # Iterate through documents matching the query's selector.
    #
    # @yieldparam [Hash] document each matching document
    def each() end

    # @return [Numeric] the number of documents that match the selector.
    def count() end

    # Update a single document matching the query's selector.
    #
    # @example
    #   db[:people].find(_id: 1).update(name: "John")
    #
    # @param [Hash] change the changes to make to the document
    def update(change) end

    # Update multiple documents matching the query's selector.
    #
    # @example
    #   db[:people].find(name: "John").update_all(name: "Mary")
    #
    # @param [Hash] change the changes to make to the documents
    def update_all(selector, change) end

    # Update an existing document with +change+, otherwise create one.
    #
    # @example
    #   db[:people].find.entries # => { name: "John" }
    #   db[:people].find(name: "John").upsert(name: "James")
    #   db[:people].find.entries # => { name: "James" }
    #   db[:people].find(name: "John").upsert(name: "Mary")
    #   db[:people].find.entries # => [{ name: "James" }, { name: "Mary" }]
    #
    # @param [Hash] change the changes to make to the the document
    def upsert(change) end

    # Remove a single document matching the query's selector.
    #
    # @example
    #   db[:people].find(name: "John").remove
    def remove() end

    # Remove multiple documents matching the query's selector.
    #
    # @example
    #   db[:people].find(name: "John").remove_all
    def remove_all() end
  end

  class Cursor
    def next() end
  end

end

require "moped/socket"
require "moped/cluster"
