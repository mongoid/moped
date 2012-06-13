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

    # @attribute [r] collection The collection to execute the query on.
    # @attribute [r] operation The query operation.
    # @attribute [r] selector The query selector.
    attr_reader :collection, :operation, :selector

    # Get the count of matching documents in the query.
    #
    # @example Get the count.
    #   db[:people].find.count
    #
    # @return [ Integer ] The number of documents that match the selector.
    #
    # @since 1.0.0
    def count
      result = collection.database.command(
        count: collection.name,
        query: selector
      )
      result["n"].to_i
    end

    # Get the distinct values in the collection for the provided key.
    #
    # @example Get the distinct values.
    #   db[:people].find.distinct(:name)
    #
    # @param [ Symbol, String ] key The name of the field.
    #
    # @return [ Array<Object ] The distinct values.
    #
    # @since 1.0.0
    def distinct(key)
      result = collection.database.command(
        distinct: collection.name,
        key: key.to_s,
        query: selector
      )
      result["values"]
    end

    # Iterate through documents matching the query's selector.
    #
    # @example Iterate over the matching documents.
    #   db[:people].find.each do |doc|
    #     #...
    #   end
    #
    # @return [ Enumerator ] The enumerator.
    #
    # @since 1.0.0
    #
    # @yieldparam [ Hash ] document each matching document
    def each
      cursor = Cursor.new(session, operation)
      cursor.to_enum.tap do |enum|
        enum.each do |document|
          yield document
        end if block_given?
      end
    end

    # Explain the current query.
    #
    # @example Explain the query.
    #   db[:people].find.explain
    #
    # @return [ Hash ] The explain document.
    #
    # @since 1.0.0
    def explain
      operation.selector = {
        "$query" => selector,
        "$orderby" => operation.selector.fetch("$orderby", {}),
        "$explain" => true
      } and first
    end

    # Get the first matching document.
    #
    # @example Get the first matching document.
    #   db[:people].find.first
    #
    # @return [ Hash ] The first document that matches the selector.
    #
    # @since 1.0.0
    def first
      reply = session.context.query(
        operation.database,
        operation.collection,
        operation.selector,
        fields: operation.fields,
        flags: operation.flags,
        skip: operation.skip,
        limit: -1
      )
      reply.documents.first
    end
    alias :one :first

    # Initialize the query.
    #
    # @example Initialize the query.
    #   Query.new(collection, selector)
    #
    # @param [ Collection ] collection The query's collection.
    # @param [ Hash ] selector The query's selector.
    #
    # @since 1.0.0
    def initialize(collection, selector)
      @collection, @selector = collection, selector
      @operation = Protocol::Query.new(
        collection.database.name,
        collection.name,
        selector
      )
    end

    # Set the query's limit.
    #
    # @example Set the limit.
    #   db[:people].find.limit(20)
    #
    # @param [ Integer ] limit The number of documents to limit.
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def limit(limit)
      operation.limit = limit
      self
    end

    # Remove a single document matching the query's selector.
    #
    # @example Remove a single document.
    #   db[:people].find(name: "John").remove
    #
    # @return [ Hash, nil ] If in safe mode the last error result.
    #
    # @since 1.0.0
    def remove
      session.with(consistency: :strong) do |session|
        session.context.remove(
          operation.database,
          operation.collection,
          operation.selector,
          flags: [ :remove_first ]
        )
      end
    end

    # Remove multiple documents matching the query's selector.
    #
    # @example Remove all matching documents.
    #   db[:people].find(name: "John").remove_all
    #
    # @return [ Hash, nil ] If in safe mode the last error result.
    #
    # @since 1.0.0
    def remove_all
      session.with(consistency: :strong) do |session|
        session.context.remove(
          operation.database,
          operation.collection,
          operation.selector
        )
      end
    end

    # Set the fields to include or exclude from the query.
    #
    # @example Select the fields to include or exclude.
    #   db[:people].find.select(name: 1).one # => { name: "John" }
    #
    # @param [ Hash ] select The inclusions or exclusions.
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def select(select)
      operation.fields = select
      self
    end

    # Set the number of documents to skip.
    #
    # @example Set the number to skip.
    #   db[:people].find.skip(20)
    #
    # @param [ Integer ] skip The number of documents to skip.
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def skip(skip)
      operation.skip = skip
      self
    end

    # Set the sort order for the query.
    #
    # @example Set the sort order.
    #   db[:people].find.sort(name: 1, age: -1).one
    #
    # @param [ Hash ] sort The order as key/(1/-1) pairs.
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def sort(sort)
      operation.selector = { "$query" => selector, "$orderby" => sort }
      self
    end

    def hint(hint)
      operation.selector = {"$query" => selector} unless operation.selector['$query']
      operation.selector['$hint'] = hint
      self
    end

    # Update a single document matching the query's selector.
    #
    # @example Update the first matching document.
    #   db[:people].find(_id: 1).update(name: "John")
    #
    # @param [ Hash ] change The changes to make to the document
    # @param [ Array ] flags An array of operation flags. Valid values are:
    #   +:multi+ and +:upsert+
    #
    # @return [ Hash, nil ] If in safe mode the last error result.
    #
    # @since 1.0.0
    def update(change, flags = nil)
      session.with(consistency: :strong) do |session|
        session.context.update(
          operation.database,
          operation.collection,
          operation.selector,
          change,
          flags: flags
        )
      end
    end

    # Update multiple documents matching the query's selector.
    #
    # @example Update multiple documents.
    #   db[:people].find(name: "John").update_all(name: "Mary")
    #
    # @param [ Hash ] change The changes to make to the documents
    #
    # @return [ Hash, nil ] If in safe mode the last error result.
    #
    # @since 1.0.0
    def update_all(change)
      update(change, [ :multi ])
    end

    # Update an existing document with +change+, otherwise create one.
    #
    # @example Upsert the changes.
    #   db[:people].find.entries # => { name: "John" }
    #   db[:people].find(name: "John").upsert(name: "James")
    #   db[:people].find.entries # => { name: "James" }
    #   db[:people].find(name: "John").upsert(name: "Mary")
    #   db[:people].find.entries # => [{ name: "James" }, { name: "Mary" }]
    #
    # @param [ Hash ] change The changes to make to the the document.
    #
    # @return [ Hash, nil ] If in safe mode the last error result.
    #
    # @since 1.0.0
    def upsert(change)
      update(change, [ :upsert ])
    end
    
    # Update an existing document with +change+ and return it
    #
    # @example
    #  db[:people].find(name: "John").modify(name: "Jon") # => [{ _id: objectId, name: "Jon" }]
    #  db[:people].find(name: "John").modify(name: "Jon", :new => false) # => [{ _id: objectId, name: "John" }]
    #  db[:people].find(name: "John").modify(name: "Jon", :upsert => true) # => [{ _id: objectId, name: "Jon" }]
    #  db[:people].find.sort(_id: -1).modify(name: "Jon") # => [{ _id: objectId, name: "Jon" }]
    #  db[:people].find(name: "John").select(name: 0).modify(name: "Jon") # => [{ _id: objectId }]
    #
    # @param [ Hash ] change The changes to make to the document
    # @param [ Hash ] options The options
    # 
    # @option options :new set to false if you want to return the original document
    # @option options :upsert set to true if you want to upsert
    #
    # @return [ Hash ] The document
    def modify(change, options = {})
      options = {
        :"new" => true,
        upsert: false
      }.merge!(options)
      
      cmd = {
        findAndModify: collection.name,
        query: selector,
        :"new" => options[:new],
        upsert: options[:upsert]
      }
      cmd[:sort] = operation.selector["$orderby"] if operation.selector["$orderby"]
      cmd[:fields] = operation.fields if operation.fields
      cmd[:update] = check_for_modifiers(change)
      
      result = collection.database.command(cmd)
      result["value"] if result
    end

    private
    
    def check_for_modifiers change
      keys = change.keys
      modifier = keys.detect { |key| key.to_s.start_with?("$") }
      if modifier && keys.size == 1
        { modifier => change[modifier] }
      else
        change.merge(selector)
      end
    end

    def session
      collection.database.session
    end
  end
end
