module Moped

  # A session in moped is root for all interactions with a MongoDB server or
  # replica set.
  #
  # It can talk to a single default database, or dynamically speak to multiple
  # databases.
  #
  # @example Single database (console-style)
  #   session = Moped::Session.new(["127.0.0.1:27017"])
  #   session.use :moped
  #   session[:users].find.one # => { name: "John" }
  #
  # @example Multiple databases
  #   session = Moped::Session.new(["127.0.0.1:27017"])
  #
  #   session.with(database: :admin) do |admin|
  #     admin.command ismaster: 1
  #   end
  #
  #   session.with(database: :moped) do |moped|
  #     moped[:users].find.one # => { name: "John" }
  #   end
  #
  # @example Authentication
  #
  #   session = Moped::Session.new %w[127.0.0.1:27017],
  #   session.with(database: "admin").login("admin", "s3cr3t")
  #
  class Session
    extend Forwardable

    # @attribute [r] cluster The session cluster.
    # @attribute [r] context The session context.
    # @attribute [r] options The session options.
    attr_reader :cluster, :context, :options

    # @method [](collection)
    # Return +collection+ from the current database.
    #
    # @param (see Moped::Database#[])
    # @return (see Moped::Database#[])
    delegate :[] => :current_database

    # @method collection_names
    # Return non system collection name from the current database.
    #
    # @param (see Moped::Database#collection_names)
    # @return (see Moped::Database#collection_names)
    delegate :collection_names => :current_database

    # @method collections
    # Return non system collection name from the current database.
    #
    # @param (see Moped::Database#collections)
    # @return (see Moped::Database#collections)
    delegate :collections => :current_database

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

    # @method login(username, password)
    # Log in with +username+ and +password+ on the current database.
    #
    # @param (see Moped::Database#login)
    # @raise (see Moped::Database#login)
    delegate :login => :current_database

    # @method logout
    # Log out from the current database.
    #
    # @param (see Moped::Database#logout)
    # @raise (see Moped::Database#login)
    delegate :logout => :current_database

    # Get the session's consistency.
    #
    # @example Get the session consistency.
    #   session.consistency
    #
    # @return [ :strong, :eventual ] The session's consistency.
    #
    # @since 1.0.0
    def consistency
      options[:consistency]
    end

    # Initialize a new database session.
    #
    # @example Initialize a new session.
    #   Session.new([ "localhost:27017" ])
    #
    # @param [ Array ] seeds an of host:port pairs
    # @param [ Hash ] options
    #
    # @option options [ Boolean ] :safe (false) Ensure writes are persisted.
    # @option options [ Hash ] :safe Ensure writes are persisted with the
    #   specified safety level e.g., "fsync: true", or "w: 2, wtimeout: 5".
    # @option options [ Symbol, String ] :database The database to use.
    # @option options [ :strong, :eventual ] :consistency (:eventual).
    #
    # @since 1.0.0
    def initialize(seeds, options = {})
      @cluster = Cluster.new(seeds, {})
      @context = Context.new(self)
      @options = options
      @options[:consistency] ||= :eventual
    end

    # Create a new session with +options+ and use new socket connections.
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
        yield session
      else
        session
      end
    end

    # Is the session operating in safe mode?
    #
    # @example Is the session operating in safe mode?
    #   session.safe?
    #
    # @return [ true, false ] Whether the current session requires safe
    #   operations.
    #
    # @since 1.0.0
    def safe?
      !!safety
    end

    # Get the safety level for the session.
    #
    # @example Get the safety level.
    #   session.safety
    #
    # @return [ Boolean, Hash ] The safety level for this session.
    #
    # @since 1.0.0
    def safety
      safe = options[:safe]
      case safe
      when false then false
      when true then { safe: true }
      else safe
      end
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
        yield session
      else
        session
      end
    end

    private

    def current_database
      return @current_database if defined? @current_database

      if database = options[:database]
        set_current_database(database)
      else
        raise "No database set for session. Call #use or #with before accessing the database"
      end
    end

    def initialize_copy(_)
      @context = Context.new(self)
      @options = @options.dup

      if defined? @current_database
        remove_instance_variable :@current_database
      end
    end

    def set_current_database(database)
      @current_database = Database.new(self, database)
    end
  end
end
