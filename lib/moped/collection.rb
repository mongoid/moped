module Moped

  # The class for interacting with a MongoDB collection.
  #
  # @example
  #   users = session[:users] # => <Moped::Collection ...>
  #   users.drop
  #   users.insert(name: "John")
  #   users.find.to_a # => [{ name: "John" }]
  class Collection

    # @attribute [r] database The collection's database.
    # @attribute [r] name The collection name.
    attr_reader :database, :name

    # Drop the collection.
    #
    # @example Drop the collection.
    #   collection.drop
    #
    # @return [ Hash ] The command information.
    #
    # @since 1.0.0
    def drop
      begin
        database.command(drop: name)
      rescue Moped::Errors::OperationFailure => e
        false
      end
    end

    # Build a query for this collection.
    #
    # @example Build a query based on the provided selector.
    #   collection.find(name: "Placebo")
    #
    # @param [ Hash ] selector The query selector.
    #
    # @return [ Query ] The generated query.
    #
    # @since 1.0.0
    def find(selector = {})
      Query.new(self, selector)
    end
    alias :where :find

    # Access information about this collection's indexes.
    #
    # @example Get the index information.
    #   collection.indexes
    #
    # @return [ Indexes ] The index information.
    #
    # @since 1.0.0
    def indexes
      Indexes.new(database, name)
    end

    # Initialize the new collection.
    #
    # @example Initialize the collection.
    #   Collection.new(database, :artists)
    #
    # @param [ Database ] database The collection's database.
    # @param [ String, Symbol] name The collection name.
    #
    # @since 1.0.0
    def initialize(database, name)
      @database, @name = database, name.to_s
    end

    # Insert one or more documents into the collection.
    #
    # @example Insert a single document.
    #   db[:people].insert(name: "John")
    #
    # @example Insert multiple documents in batch.
    #   db[:people].insert([{name: "John"}, {name: "Joe"}])
    #
    # @param [ Hash, Array<Hash> ] documents The document(s) to insert.
    # @param [ Array ] flags The flags, valid values are :continue_on_error.
    #
    # @option options [Array] :continue_on_error Whether to continue on error.
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def insert(documents, flags = nil)
      documents = [documents] unless documents.is_a?(Array)
      database.session.with(consistency: :strong) do |session|
        session.context.insert(database.name, name, documents, flags: flags || [])
      end
    end
  end
end
