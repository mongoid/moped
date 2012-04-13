module Moped

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
      operation.selector = { "$query" => selector, "$orderby" => sort }
      self
    end

    # Explain the current query.
    #
    # @example Explain the query.
    #   db[:people].find.explain
    #
    # @return [ Hash ] The explain document.
    def explain
      operation.selector = {
        "$query" => selector,
        "$orderby" => operation.selector.fetch("$orderby", {}),
        "$explain" => true
      } and first
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
    def first
      session.simple_query(operation)
    end
    alias one first

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

    # Get the distinct values in the collection for the provided key.
    #
    # @example Get the distinct values.
    #   query.distinct(:name)
    #
    # @param [ Symbol, String ] key The name of the field.
    #
    # @return [ Array<Object ] The distinct values.
    def distinct(key)
      result = collection.database.command(
        distinct: collection.name,
        key: key.to_s,
        query: selector
      )
      result["values"]
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
