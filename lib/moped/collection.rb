# encoding: utf-8
require "moped/query"

module Moped

  # The class for interacting with a MongoDB collection.
  #
  # @since 1.0.0
  class Collection
    include Readable

    # @!attribute database
    #   @return [ Database ] The database for the collection.
    # @!attribute name
    #   @return [ String ] The name of the collection.
    attr_reader :database, :name

    # Return whether or not this collection is a capped collection.
    #
    # @example Is the collection capped?
    #   collection.capped?
    #
    # @return [ true, false ] If the collection is capped.
    #
    # @since 1.4.0
    def capped?
      database.command(collstats: name)["capped"]
    end

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
        session.with(read: :primary).command(drop: name)
      rescue Moped::Errors::OperationFailure => e
        raise e unless e.ns_not_found?
        false
      end
    end

    # Rename the collection
    #
    # @example Rename the collection to 'foo'
    #   collection.rename('foo')
    #
    # @return [ Hash ] The command information.
    #
    # @since 2.0.0
    def rename(to_name)
      begin
        session.
          with(database: "admin", read: :primary).
          command(renameCollection: "#{database.name}.#{name}", to: "#{database.name}.#{to_name}")
      rescue Moped::Errors::OperationFailure => e
        raise e unless e.ns_not_exists?
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
      @database = database
      @name = name.to_s
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
      docs = documents.is_a?(Array) ? documents : [ documents ]
      cluster.with_primary do |node|
        node.insert(database.name, name, docs, write_concern, flags: flags || [])
      end
    end

    # Call aggregate function over the collection.
    #
    # @example Execute an aggregation.
    #   session[:users].aggregate({
    #     "$group" => {
    #       "_id" => "$city",
    #       "totalpop" => { "$sum" => "$pop" }
    #     }
    #   })
    #
    # @param [ Hash, Array<Hash> ] documents representing the aggregate
    #   function to execute
    #
    # @return [ Hash ] containing the result of aggregation
    #
    # @since 1.3.0
    def aggregate(*pipeline)
      session.command(aggregate: name, pipeline: pipeline.flatten)["result"]
    end

    # Get the session for the collection.
    #
    # @example Get the session for the collection.
    #   collection.session
    #
    # @return [ Session ] The session for the collection.
    #
    # @since 2.0.0
    def session
      database.session
    end

    def write_concern
      session.write_concern
    end
  end
end
