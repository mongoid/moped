# encoding: utf-8
module Moped

  # The class for interacting with a MongoDB database. One only interacts with
  # this class indirectly through a session.
  #
  # @since 1.0.0
  class Database

    # @!attribute name
    #   @return [ String ] The name of the database.
    # @!attribute session
    #   @return [ Session ] The database session.
    attr_reader :name, :session

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

    # Get all non-system collections from the database.
    #
    # @example Get all the collections.
    #   database.collections
    #
    # @return [ Array<Collection> ] All the collections.
    #
    # @since 1.0.0
    def collections
      collection_names.map{ |name| Collection.new(self, name) }
    end

    # Get all non-system collection names from the database, this excludes
    # indexes.
    #
    # @example Get all the collection names.
    #   database.collection_names
    #
    # @return [ Array<String> ] The names of all collections.
    #
    # @since 1.0.0
    def collection_names
      namespaces = self["system.namespaces"].find(name: { "$not" => /#{name}\.system\.|\$/ })
      namespaces.map do |doc|
        _name = doc["name"]
        _name[name.length + 1, _name.length]
      end
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
      read(Protocol::Command.new(name, command, query_options))
    end

    # Drop the database.
    #
    # @example Drop the database.
    #   database.drop
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def drop
      session.with(read: :primary) do |session|
        session.command(dropDatabase: 1)
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
      @session = session
      @name = name.to_s
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
      cluster.credentials[name] = [ username, password ]
    end

    # Log out from the current database.
    #
    # @example Logout from the current database.
    #   session.logout
    #
    # @since 1.0.0
    def logout
      cluster.credentials.delete(name)
    end

    private

    # Convenience method for getting the cluster from the session.
    #
    # @api private
    #
    # @example Get the cluster from the session.
    #   database.cluster
    #
    # @return [ Cluster ] The cluster.
    #
    # @since 2.0.0
    def cluster
      session.cluster
    end

    # Execute a read operation on the correct node.
    #
    # @api private
    #
    # @example Execute a read.
    #   database.read(operation)
    #
    # @param [ Protocol::Command ] operation The read operation.
    #
    # @return [ Object ] The result of the operation.
    #
    # @since 2.0.0
    def read(operation)
      read_preference.with_node(cluster) do |node|
        Operation::Read.new(operation).execute(node)
      end
    end

    # Convenience method for getting the read preference from the session.
    #
    # @api private
    #
    # @example Get the read preference.
    #   database.read_preference
    #
    # @return [ Object ] The session's read preference.
    #
    # @since 2.0.0
    def read_preference
      session.read_preference
    end

    # Get the query options from the read preference.
    #
    # @api private
    #
    # @example Get the query options.
    #   database.query_options
    #
    # @param [ Hash ] options The existing options on the query.
    #
    # @return [ Hash ] The new query options.
    #
    # @since 2.0.0
    def query_options(options = {})
      read_preference.query_options(options)
    end
  end
end
