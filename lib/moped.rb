require "crutches/bson"
require "crutches/protocol"
require "monitor"
require "forwardable"

module Moped
  BSON = Crutches::BSON
  Protocol = Crutches::Protocol

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
    # @option options [:strong, :eventual] :consistency (:eventual)
    def initialize(seeds, options = {})
      @cluster = Cluster.new(seeds)
      @options = options
      @options[:consistency] ||= :eventual
    end

    # @return [Boolean] whether the current session requires safe operations.
    def safe?
      !!safety
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
    # @return [Moped::Session, Object] the new session, or the value returned
    #   by the block if provided.
    def with(options = {})
      session = dup
      session.options.update options

      if block_given?
        yield session
      else
        session
      end
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

    def current_database
      return @current_database if defined? @current_database

      if database = options[:database]
        set_current_database(database)
      else
        raise "No database set for session. Call #use or #with before accessing the database"
      end
    end

    # @api private
    def simple_query(query)
      query.limit = -1

      query(query).documents.first
    end

    # @api private
    def query(query)
      if options[:consistency] == :eventual
        query.flags |= [:slave_ok] if query.respond_to? :flags
        mode = :read
      else
        mode = :write
      end

      reply = socket_for(mode).execute(query)

      reply.tap do |reply|
        if reply.flags.include?(:query_failure)
          raise Errors::QueryFailure.new(query, reply.documents.first)
        end
      end
    end

    # @api private
    def execute(op)
      mode = options[:consistency] == :eventual ? :read : :write
      socket = socket_for(mode)

      if safe?
        last_error = Protocol::Command.new(
          "admin", { getlasterror: 1 }.merge(safety)
        )

        socket.execute(op, last_error).documents.first.tap do |result|
          raise Errors::OperationFailure.new(
            op, result
          ) if result["err"] || result["errmsg"]
        end
      else
        socket.execute(op)
      end
    end

    private

    # @return [Boolean, Hash] the safety level for this session
    def safety
      safe = options[:safe]

      case safe
      when false
        false
      when true
        { safe: true }
      else
        safe
      end
    end

    def socket_for(mode)
      if options[:retain_socket]
        @socket ||= cluster.socket_for(mode)
      else
        cluster.socket_for(mode)
      end
    end

    def set_current_database(database)
      @current_database = Database.new(self, database)
    end

    def dup
      session = super
      session.instance_variable_set :@options, options.dup

      if defined? @current_database
        session.send(:remove_instance_variable, :@current_database)
      end

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
      operation = Protocol::Command.new(name, command)

      result = session.with(consistency: :strong) do |session|
        session.simple_query(operation)
      end

      raise Errors::OperationFailure.new(
        operation, result
      ) unless result["ok"] == 1.0

      result
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

    # Build a query for this collection.
    #
    # @param [Hash] selector the selector
    # @return [Moped::Query]
    def find(selector = {})
      Query.new self, selector
    end
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
      insert = Protocol::Insert.new(database.name, name, documents)

      database.session.with(consistency: :strong) do |session|
        session.execute insert
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

    # @return [Collection] the query's collection
    attr_reader :collection

    # @return [Hash] the query's selector
    attr_reader :selector

    # @api private
    attr_reader :operation

    # @param [Collection] collection the query's collection
    # @param [Hash] selector the query's selector
    def initialize(collection, selector)
      @collection = collection
      @selector = selector

      @operation = Protocol::Query.new(
        collection.database.name,
        collection.name,
        selector
      )
    end

    # Set the query's limit.
    #
    # @param [Numeric] limit
    # @return [Query] self
    def limit(limit)
      operation.limit = limit
      self
    end

    # Set the number of documents to skip.
    #
    # @param [Numeric] skip
    # @return [Query] self
    def skip(skip)
      operation.skip = skip
      self
    end

    # Set the sort order for the query.
    #
    # @example
    #   db[:people].find.sort(name: 1, age: -1).one
    #
    # @param [Hash] sort
    # @return [Query] self
    def sort(sort)
      operation.selector = {"$query" => selector, "$orderby" => sort}
      self
    end

    # Set the fields to return from the query.
    #
    # @example
    #   db[:people].find.select(name: 1).one # => { name: "John" }
    #
    # @param [Hash] select
    # @return [Query] self
    def select(select)
      operation.fields = select
      self
    end

    # @return [Hash] the first document that matches the selector.
    def one()
      session.simple_query(operation)
    end
    alias first one

    # Iterate through documents matching the query's selector.
    #
    # @yieldparam [Hash] document each matching document
    def each
      cursor = Cursor.new(session.with(retain_socket: true), operation)
      cursor.to_enum.tap do |enum|
        enum.each do |document|
          yield document
        end if block_given?
      end
    end

    # @return [Numeric] the number of documents that match the selector.
    def count
      result = collection.database.command(
        count: collection.name,
        query: selector
      )

      result["n"]
    end

    # Update a single document matching the query's selector.
    #
    # @example
    #   db[:people].find(_id: 1).update(name: "John")
    #
    # @param [Hash] change the changes to make to the document
    # @param [Array] flags an array of operation flags. Valid values are:
    #   +:multi+ and +:upsert+
    def update(change, flags = nil)
      update = Protocol::Update.new(
        operation.database,
        operation.collection,
        operation.selector,
        change,
        flags: flags
      )

      session.with(consistency: :strong) do |session|
        session.execute update
      end
    end

    # Update multiple documents matching the query's selector.
    #
    # @example
    #   db[:people].find(name: "John").update_all(name: "Mary")
    #
    # @param [Hash] change the changes to make to the documents
    def update_all(change)
      update change, [:multi]
    end

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
    def upsert(change)
      update change, [:upsert]
    end

    # Remove a single document matching the query's selector.
    #
    # @example
    #   db[:people].find(name: "John").remove
    def remove
      delete = Protocol::Delete.new(
        operation.database,
        operation.collection,
        operation.selector,
        flags: [:remove_first]
      )

      session.with(consistency: :strong) do |session|
        session.execute delete
      end
    end

    # Remove multiple documents matching the query's selector.
    #
    # @example
    #   db[:people].find(name: "John").remove_all
    def remove_all
      delete = Protocol::Delete.new(
        operation.database,
        operation.collection,
        operation.selector
      )

      session.with(consistency: :strong) do |session|
        session.execute delete
      end
    end

    private

    def session
      collection.database.session
    end
  end

end

require "moped/server"
require "moped/socket"
require "moped/cluster"
require "moped/cursor"
require "moped/errors"
