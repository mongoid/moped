# encoding: utf-8
require "moped/cursor"

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
  #   people.find(name: nil).update_all("$set" => { name: "Unknown" })
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
    def count(limit = false)
      command = { count: collection.name, query: selector }
      command.merge!(skip: operation.skip, limit: operation.limit) if limit
      result = collection.database.command(command)
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
    # @return [ Enumerable ]
    #
    # @since 1.0.0
    #
    # @yieldparam [ Hash ] document each matching document
    def each(*args, &blk)
      cursor.each(*args, &blk)
    end

    # Get the Moped cursor to iterate over documents
    # on the db.
    #
    # @example Iterate over the matching documents.
    #   db[:people].cursor.each do |doc|
    #     #...
    #   end
    #
    # @return [ Moped::Cursor ]
    #
    # @since 2.0.0
    def cursor
      Cursor.new(session, operation)
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
      explanation = operation.selector.dup
      hint = explanation["$hint"]
      sort = explanation["$orderby"]
      max_scan = explanation["$maxScan"]
      explanation = {
        "$query" => selector,
        "$explain" => true,
      }
      explanation["$orderby"] = sort if sort
      explanation["$hint"] = hint if hint
      explanation["$maxScan"] = max_scan if max_scan
      Query.new(collection, explanation).limit(-(operation.limit.abs)).each { |doc| return doc }
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
      reply = read_preference.with_node(cluster) do |node|
        node.query(
          operation.database,
          operation.collection,
          operation.selector,
          query_options(
            fields: operation.fields,
            flags: operation.flags,
            skip: operation.skip,
            limit: -1
          )
        )
      end
      reply.documents.first
    end
    alias :one :first

    # Apply an index hint to the query.
    #
    # @example Apply an index hint.
    #   db[:people].find.hint("$natural" => 1)
    #
    # @param [ Hash ] hint The index hint.
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def hint(hint)
      upgrade_to_advanced_selector
      operation.selector["$hint"] = hint
      self
    end

    # Apply a max scan limit to the query.
    #
    # @example Limit the query to only scan up to 100 documents
    #   db[:people].find.max_scan(100)
    #
    # @param [ Integer ] max The maximum number of documents to scan
    #
    # @return [ Query ] self
    #
    # @since 1.4.0
    def max_scan(max)
      upgrade_to_advanced_selector
      operation.selector["$maxScan"] = max
      self
    end

    # Specify the inclusive lower bound for a specific index in order to
    # constrain the results of find(). min() provides a way to specify lower
    # bounds on compound key indexes.
    #
    # @example Set the lower bond on the age index to 21 years
    # (provided the collection has a {"age" => 1} index)
    #   db[:people].find.min("age" => 21)
    #
    # @param [ Hash ] indexBounds The inclusive lower bound for the index keys.
    #
    # @return [ Query ] self
    #
    def min(index_bounds)
      upgrade_to_advanced_selector
      operation.selector["$min"] = index_bounds
      self
    end

    # Specifies the exclusive upper bound for a specific index in order to
    # constrain the results of find().  max() provides a way to specify an
    # upper bound on compound key indexes.
    #
    # @example Set the upper bond on the age index to 21 years
    # (provided the collection has a {"age" => -11} index)
    #   db[:people].find.min("age" => 21)
    #
    # @param [ Hash ] indexBounds The exclusive upper bound for the index keys.
    #
    # @return [ Query ] self
    #
    def max(index_bounds)
      upgrade_to_advanced_selector
      operation.selector["$max"] = index_bounds
      self
    end

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

    # Set the query's batch size.
    #
    # @example Set the batch size.
    #   db[:people].find.batch_size(20)
    #
    # @param [ Integer ] limit The number of documents per batch.
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def batch_size(batch_size)
      operation.batch_size = batch_size
      self
    end

    # Disable cursor timeout
    #
    # @example Disable cursor timeout.
    #   db[:people].find.no_timeout
    #
    # @return [ Query ] self
    #
    # @since 1.0.0
    def no_timeout
      operation.no_timeout = true
      self
    end

    # Execute a $findAndModify on the query.
    #
    # @example Find and modify a document, returning the original.
    #   db[:bands].find.modify({ "$inc" => { likes: 1 }})
    #
    # @example Find and modify a document, returning the updated document.
    #   db[:bands].find.modify({ "$inc" => { likes: 1 }}, new: true)
    #
    # @example Find and return a document, removing it from the database.
    #   db[:bands].find.modify({}, remove: true)
    #
    # @example Find and return a document, upserting if no match found.
    #   db[:bands].find.modify({}, upsert: true, new: true)
    #
    # @param [ Hash ] change The changes to make to the document.
    # @param [ Hash ] options The options.
    #
    # @option options :new Set to true if you want to return the updated document.
    # @option options :remove Set to true if the document should be deleted.
    # @option options :upsert Set to true if you want to upsert
    #
    # @return [ Hash ] The document.
    #
    # @since 1.0.0
    def modify(change, options = {})
      command = {
        findAndModify: collection.name,
        query: selector
      }.merge(options)

      command[:sort] = operation.selector["$orderby"] if operation.selector["$orderby"]
      command[:fields] = operation.fields if operation.fields
      command[:update] = change unless options[:remove]

      result = session.with(read: :primary) do |sess|
        sess.command(command)["value"]
      end

      # Keeping moped compatibility with mongodb >= 2.2.0-rc0
      options[:upsert] && !result ? {} : result
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
      cluster.with_primary do |node|
        node.remove(
          operation.database,
          operation.collection,
          operation.basic_selector,
          write_concern,
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
      cluster.with_primary do |node|
        node.remove(
          operation.database,
          operation.collection,
          operation.basic_selector,
          write_concern
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
      upgrade_to_advanced_selector
      operation.selector["$orderby"] = sort
      self
    end

    # Tell the query to create a tailable cursor.
    #
    # @example Tell the query the cursor is tailable.
    #   db[:people].find.tailable
    #
    # @return [ Query ] The query.
    #
    # @since 1.3.0
    def tailable
      operation.flags.push(:tailable, :await_data)
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
      cluster.with_primary do |node|
        node.update(
          operation.database,
          operation.collection,
          operation.selector["$query"] || operation.selector,
          change,
          write_concern,
          flags: flags
        )
      end
    end

    # Update multiple documents matching the query's selector.
    #
    # @example Update multiple documents.
    #   db[:people].find(name: "John").update_all("$set" => { name: "Mary" })
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

    def write_concern
      session.write_concern
    end

    def read_preference
      session.read_preference
    end

    def cluster
      session.cluster
    end

    def query_options(options)
      read_preference.query_options(options)
    end

    private

    def initialize_copy(other)
      @operation = other.operation.dup
      @selector = other.selector.dup
    end

    def session
      collection.database.session
    end

    def upgrade_to_advanced_selector
      operation.selector = { "$query" => selector } unless operation.selector["$query"]
    end
  end
end
