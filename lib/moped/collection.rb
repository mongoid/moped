module Moped

  # The class for interacting with a MongoDB collection.
  #
  # @example
  #   users = session[:users] # => <Moped::Collection ...>
  #   users.drop
  #   users.insert(name: "John")
  #   users.find.to_a # => [{ name: "John" }]
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

    # Access information about this collection's indexes.
    #
    # @return [Indexes]
    def indexes
      Indexes.new(database, name)
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
end
