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
        database.session.with(consistency: :strong) do |session|
          session.context.command(database.name, drop: name)
        end
      rescue Moped::Errors::OperationFailure => e
        raise e unless e.details["errmsg"] == "ns not found"
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
    # @param [ Hash, Array<Hash> ] documents representing the aggregate function to execute
    #
    # @return [ Hash ] containing the result of aggregation
    #
    # @since 1.3.0
    def aggregate(*pipeline)
      pipeline.flatten!
      command = { aggregate: name.to_s, pipeline: pipeline }
      database.session.command(command)["result"]
    end
  end
end
