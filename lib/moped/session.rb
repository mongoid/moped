# encoding: utf-8
require "moped/read_preference"
require "moped/readable"
require "moped/write_concern"
require "moped/collection"
require "moped/cluster"
require "moped/database"

module Moped

  # A session in moped is root for all interactions with a MongoDB server or
  # replica set.
  #
  # It can talk to a single default database, or dynamically speak to multiple
  # databases.
  #
  # @example Single database (console-style)
  #   session = Moped::Session.new(["127.0.0.1:27017"])
  #   session.use(:moped)
  #   session[:users].find.one
  #
  # @example Multiple databases
  #   session = Moped::Session.new(["127.0.0.1:27017"])
  #   session.with(database: :admin) do |admin|
  #     admin.command(ismaster: 1)
  #   end
  #
  # @example Authentication
  #   session = Moped::Session.new %w[127.0.0.1:27017],
  #   session.with(database: "admin").login("admin", "s3cr3t")
  #
  # @since 1.0.0
  class Session
    include Optionable

    # @!attribute cluster
    #   @return [ Cluster ] The cluster of nodes.
    # @!attribute options
    #   @return [ Hash ] The configuration options.
    attr_reader :cluster, :options

    # Return +collection+ from the current database.
    #
    # @param (see Moped::Database#[])
    #
    # @return (see Moped::Database#[])
    #
    # @since 1.0.0
    def [](name)
      current_database[name]
    end

    # Return non system collection name from the current database.
    #
    # @param (see Moped::Database#collection_names)
    #
    # @return (see Moped::Database#collection_names)
    #
    # @since 1.0.0
    def collection_names
      current_database.collection_names
    end

    # Return non system collection name from the current database.
    #
    # @param (see Moped::Database#collections)
    #
    # @return (see Moped::Database#collections)
    #
    # @since 1.0.0
    def collections
      current_database.collections
    end

    # Run +command+ on the current database.
    #
    # @param (see Moped::Database#command)
    #
    # @return (see Moped::Database#command)
    #
    # @since 1.0.0
    def command(op)
      current_database.command(op)
    end

    # Get a list of all the database names for the session.
    #
    # @example Get all the database names.
    #   session.database_names
    #
    # @note This requires admin access on your server.
    #
    # @return [ Array<String>] All the database names.
    #
    # @since 1.2.0
    def database_names
      databases["databases"].map { |database| database["name"] }
    end

    # Get information on all databases for the session. This includes the name,
    # size on disk, and if it is empty or not.
    #
    # @example Get all the database information.
    #   session.databases
    #
    # @note This requires admin access on your server.
    #
    # @return [ Hash ] The hash of database information, under the "databases"
    #   key.
    #
    # @since 1.2.0
    def databases
      with(database: :admin).command(listDatabases: 1)
    end

    # Disconnects all nodes in the session's cluster. This should only be used
    # in cases # where you know you're not going to use the cluster on the
    # thread anymore and need to force the connections to close.
    #
    # @return [ true ] True if the disconnect succeeded.
    #
    # @since 1.2.0
    def disconnect
      cluster.disconnect
    end

    # Drop the current database.
    #
    # @param (see Moped::Database#drop)
    #
    # @return (see Moped::Database#drop)
    #
    # @since 1.0.0
    def drop
      current_database.drop
    end

    # Provide a string inspection for the session.
    #
    # @example Inspect the session.
    #   session.inspect
    #
    # @return [ String ] The string inspection.
    #
    # @since 1.4.0
    def inspect
      "<#{self.class.name} seeds=#{cluster.seeds} database=#{current_database_name}>"
    end

    # Log in with +username+ and +password+ on the current database.
    #
    # @param (see Moped::Database#login)
    #
    # @raise (see Moped::Database#login)
    #
    # @since 1.0.0
    def login(username, password)
      current_database.login(username, password)
    end

    # Log out from the current database.
    #
    # @param (see Moped::Database#logout)
    #
    # @raise (see Moped::Database#login)
    #
    # @since 1.0.0
    def logout
      current_database.logout
    end

    # Setup validation of allowed write concern options.
    #
    # @since 2.0.0
    option(:write).allow({ w: Optionable.any(Integer) }, { "w" => Optionable.any(Integer) })
    option(:write).allow({ w: Optionable.any(String) }, { "w" => Optionable.any(String) })
    option(:write).allow({ j: true }, { "j" => true })
    option(:write).allow({ j: false }, { "j" => false })
    option(:write).allow({ fsync: true }, { "fsync" => true })
    option(:write).allow({ fsync: false }, { "fsync" => false })

    # Setup validation of allowed read preference options.
    #
    # @since 2.0.0
    option(:read).allow(
      :nearest,
      :primary,
      :primary_preferred,
      :secondary,
      :secondary_preferred,
      "nearest",
      "primary",
      "primary_preferred",
      "secondary",
      "secondary_preferred"
    )

    # Setup validation of allowed database options. (Any string or symbol)
    #
    # @since 2.0.0
    option(:database).allow(Optionable.any(String), Optionable.any(Symbol))

    # Setup validation of allowed max retry options. (Any integer)
    #
    # @since 2.0.0
    option(:max_retries).allow(Optionable.any(Integer))

    # Setup validation of allowed pool size options. (Any integer)
    #
    # @since 2.0.0
    option(:pool_size).allow(Optionable.any(Integer))

    # Setup validation of allowed retry interval options. (Any numeric)
    #
    # @since 2.0.0
    option(:retry_interval).allow(Optionable.any(Numeric))

    # Setup validation of allowed refresh interval options. (Any numeric)
    #
    # @since 2.0.0
    option(:refresh_interval).allow(Optionable.any(Numeric))

    # Setup validation of allowed down interval options. (Any numeric)
    #
    # @since 2.0.0
    option(:down_interval).allow(Optionable.any(Numeric))

    # Setup validation of allowed ssl options. (Any boolean)
    #
    # @since 2.0.0
    option(:ssl).allow(true, false)

    # Setup validation of allowed timeout options. (Any numeric)
    #
    # @since 2.0.0
    option(:timeout).allow(Optionable.any(Numeric))

    # Pass an object that responds to instrument as an instrumenter.
    #
    # @since 2.0.0
    option(:instrumenter).allow(Optionable.any(Object))

    # Setup validation of allowed auto_discover preference options.
    #
    # @since 1.5.0
    option(:auto_discover).allow(true, false)

    # Initialize a new database session.
    #
    # @example Initialize a new session.
    #   Session.new([ "localhost:27017" ])
    #
    # @param [ Array ] seeds An array of host:port pairs.
    # @param [ Hash ] options The options for the session.
    #
    # @see Above options validations for allowed values in the options hash.
    #
    # @since 1.0.0
    def initialize(seeds, options = {})
      validate_strict(options)
      @options = options
      @cluster = Cluster.new(seeds, options)
    end

    # Create a new session with +options+ and use new socket connections.
    #
    # @example Change safe mode
    #   session.with(write: { w: 2 })[:people].insert(name: "Joe")
    #
    # @example Change safe mode with block
    #   session.with(write: { w: 2 }) do |session|
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
    # @param [ Hash ] options The options.
    #
    # @return [ Session ] The new session.
    #
    # @see #with
    #
    # @since 1.0.0
    #
    # @yieldparam [ Session ] session The new session.
    def new(options = {})
      session = with(options)
      session.instance_variable_set(:@cluster, cluster.dup)
      if block_given?
        yield(session)
      else
        session
      end
    end

    # Get the read preference for the session. Will default to primary if none
    # was provided.
    #
    # @example Get the session's read preference.
    #   session.read_preference
    #
    # @return [ Object ] The read preference.
    #
    # @since 2.0.0
    def read_preference
      @read_preference ||= ReadPreference.get(options[:read] || :primary)
    end

    # Switch the session's current database.
    #
    # @example Switch the current database.
    #   session.use :moped
    #   session[:people].find.one # => { :name => "John" }
    #
    # @param [ String, Symbol ] database The database to use.
    #
    # @since 1.0.0
    def use(database)
      options[:database] = database
      set_current_database(database)
    end

    # Create a new session with +options+ reusing existing connections.
    #
    # @example Change safe mode
    #   session.with(write: { w: 2 })[:people].insert(name: "Joe")
    #
    # @example Change safe mode with block
    #   session.with(write: { w: 2 }) do |session|
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
    # @param [ Hash ] options The session options.
    #
    # @return [ Session, Object ] The new session, or the value returned
    #   by the block if provided.
    #
    # @since 1.0.0
    #
    # @yieldparam [ Session ] session The new session.
    def with(options = {})
      session = dup
      session.options.update(options)
      if block_given?
        yield(session)
      else
        session
      end
    end

    # Get the write concern for the session. Will default to propagate if none
    # was provided.
    #
    # @example Get the session's write concern.
    #   session.write_concern
    #
    # @return [ Object ] The write concern.
    #
    # @since 2.0.0
    def write_concern
      @write_concern ||= WriteConcern.get(options[:write] || { w: 1 })
    end

    class << self

      # Create a new session from a URI.
      #
      # @example Initialize a new session.
      #   Session.connect("mongodb://localhost:27017/my_db")
      #
      # @param [ String ] MongoDB URI formatted string.
      #
      # @return [ Session ] The new session.
      #
      # @since 3.0.0
      def connect(uri)
        uri = Uri.new(uri)
        session = new(*uri.moped_arguments)
        session.login(uri.username, uri.password) if uri.auth_provided?
        session
      end
    end

    private

    # Get the database that the session is currently using.
    #
    # @api private
    #
    # @example Get the current database.
    #   session.current_database
    #
    # @return [ Database ] The current database or nil.
    #
    # @since 2.0.0
    def current_database
      return @current_database if @current_database
      if database = options[:database]
        set_current_database(database)
      else
        raise "No database set for session. Call #use or #with before accessing the database"
      end
    end

    def current_database_name
      @current_database ? current_database.name : :none
    end

    def initialize_copy(_)
      @options = @options.dup
      @read_preference = nil
      @write_concern = nil
      @current_database = nil
    end

    def set_current_database(database)
      @current_database = Database.new(self, database)
    end
  end
end
