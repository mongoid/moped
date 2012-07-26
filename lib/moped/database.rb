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

    # @attribute [r] name The name of the database.
    # @attribute [r] session The session.
    attr_reader :name, :session

    # Drop the database.
    #
    # @example Drop the database.
    #   database.drop
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def drop
      session.with(consistency: :strong) do |session|
        session.context.command(name, dropDatabase: 1)
      end
    end

    # Initialize the database.
    #
    # @example Initialize a database object.
    #   Database.new(session, :artists)
    #
    # @param [ Session ] session The session.
    # @param [ String, Symbol ] name The name of the database.
    #
    # @since 1.0.0
    def initialize(session, name)
      @session, @name = session, name
      raise NameError, "#{ @name.inspect } is not a valid mongo database name." if @name =~ %r/[\s\.]/iomx
    end

    # Log in with +username+ and +password+ on the current database.
    #
    # @example Authenticate against the database.
    #   session.login("user", "pass")
    #
    # @param [ String ] username The username.
    # @param [ String ] password The password.
    #
    # @since 1.0.0
    def login(username, password)
      session.context.login(name, username, password)
    end

    # Log out from the current database.
    #
    # @example Logout from the current database.
    #   session.logout
    #
    # @since 1.0.0
    def logout
      session.context.logout(name)
    end

    # Run +command+ on the database.
    #
    # @example Run a command.
    #   db.command(ismaster: 1)
    #   # => { "master" => true, hosts: [] }
    #
    # @param [ Hash ] command The command to run.
    #
    # @return [ Hash ] the result of the command.
    #
    # @since 1.0.0
    def command(command)
      session.context.command name, command
    end

    # Get a collection by the provided name.
    #
    # @example Get a collection.
    #   session[:users]
    #
    # @param [ Symbol, String ] collection The collection name.
    #
    # @return [ Collection ] An instance of the collection.
    #
    # @since 1.0.0
    def [](collection)
      Collection.new(self, collection)
    end

    # Get all non-system collections from the database
    #
    # @example
    #   database.collections
    #
    # @since 1.0.0
    def collections
      collection_names.map{|name| Collection.new(self, name)}
    end

    # Get all non-system collection names from the database
    #
    # @example
    #   database.collection_names
    #
    # @since 1.0.0
    def collection_names
      Collection.new(self, "system.namespaces").
        find(name: { "$not" => /system|\$/ }).to_a.
          map{|collection| collection["name"].split(".", 2).last}
    end
  end
end
