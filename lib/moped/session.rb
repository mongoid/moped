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

    # @attribute [r] cluster The session cluster.
    # @attribute [r] context The session context.
    # @attribute [r] options The session options.
    attr_reader :cluster, :context, :options

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
    # @option options [ Boolean ] :ssl Connect using SSL.
    # @option options [ Integer ] :max_retries The maximum number of attempts
    #   to retry an operation. (30)
    # @option options [ Integer ] :retry_interval The time in seconds to retry
    #   connections to a secondary or primary after a failure. (1)
    # @option options [ Integer ] :timeout The time in seconds to wait for an
    #   operation to timeout. (5)
    #
    # @since 1.0.0
    def initialize(seeds, options = {})
      @cluster = Cluster.new(seeds, options)
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
        yield(session)
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
      options[:safe].__safe_options__
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
        yield(session)
      else
        session
      end
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
        uri = MongoUri.new(uri)
        session = new(*uri.moped_arguments)
        session.login(uri.username, uri.password) if uri.auth_provided?
        session
      end
    end

    private

    def current_database
      return @current_database if defined?(@current_database)
      if database = options[:database]
        set_current_database(database)
      else
        raise "No database set for session. Call #use or #with before accessing the database"
      end
    end

    def current_database_name
      defined?(@current_database) ? current_database.name : :none
    end

    def initialize_copy(_)
      @context = Context.new(self)
      @options = @options.dup
      if defined?(@current_database)
        remove_instance_variable(:@current_database)
      end
    end

    def set_current_database(database)
      @current_database = Database.new(self, database)
    end
  end
end
