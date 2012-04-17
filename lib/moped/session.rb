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

    # @return [Hash] this session's options
    attr_reader :options

    # @private
    # @return [Cluster] this session's cluster
    attr_reader :cluster

    # @private
    # @return [Context] this session's context
    attr_reader :context

    # @param [Array] seeds an of host:port pairs
    # @param [Hash] options
    # @option options [Boolean] :safe (false) ensure writes are persisted
    # @option options [Hash] :safe ensure writes are persisted with the
    #   specified safety level e.g., "fsync: true", or "w: 2, wtimeout: 5"
    # @option options [Symbol, String] :database the database to use
    # @option options [:strong, :eventual] :consistency (:eventual)
    def initialize(seeds, options = {})
      @cluster = Cluster.new(seeds, {})
      @context = Context.new(self)
      @options = options
      @options[:consistency] ||= :eventual
    end

    # @return [Boolean] whether the current session requires safe operations.
    def safe?
      !!safety
    end

    # @return [:strong, :eventual] the session's consistency
    def consistency
      options[:consistency]
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
      session = with(options)
      session.instance_variable_set(:@cluster, cluster.dup)

      if block_given?
        yield session
      else
        session
      end
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

    private

    def current_database
      return @current_database if defined? @current_database

      if database = options[:database]
        set_current_database(database)
      else
        raise "No database set for session. Call #use or #with before accessing the database"
      end
    end

    def set_current_database(database)
      @current_database = Database.new(self, database)
    end

    def initialize_copy(_)
      @context = Context.new(self)
      @options = @options.dup

      if defined? @current_database
        remove_instance_variable :@current_database
      end
    end
  end
end
