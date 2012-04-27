module Moped
  class Indexes
    include Enumerable

    private

    def database
      @database
    end

    def collection_name
      @collection_name
    end

    def namespace
      @namespace
    end

    def initialize(database, collection_name)
      @database = database
      @collection_name = collection_name
      @namespace = "#{database.name}.#{collection_name}"
    end

    public

    # Retrive an index by its definition.
    #
    # @param [Hash] key an index key definition
    # @return [Hash, nil] the index with the provided key, or nil.
    #
    # @example
    #   session[:users].indexes[id: 1]
    #   # => {"v"=>1, "key"=>{"_id"=>1}, "ns"=>"moped_test.users", "name"=>"_id_" }
    def [](key)
      database[:"system.indexes"].find(ns: namespace, key: key).one
    end

    # Create an index unless it already exists.
    #
    # @param [Hash] key the index spec
    # @param [Hash] options the options for the index.
    # @see http://www.mongodb.org/display/DOCS/Indexes#Indexes-CreationOptions
    #
    # @example Without options
    #   session[:users].indexes.create(name: 1)
    #   session[:users].indexes[name: 1]
    #   # => {"v"=>1, "key"=>{"name"=>1}, "ns"=>"moped_test.users", "name"=>"name_1" }
    #
    # @example With options
    #   session[:users].indexes.create(
    #     { location: "2d", name: 1 },
    #     { unique: true, dropDups: true }
    #   )
    #   session[:users][location: "2d", name: 1]
    #   {"v"=>1,
    #     "key"=>{"location"=>"2d", "name"=>1},
    #     "unique"=>true,
    #     "ns"=>"moped_test.users",
    #     "dropDups"=>true,
    #     "name"=>"location_2d_name_1"}
    def create(key, options = {})
      spec = options.merge(ns: namespace, key: key)
      spec[:name] ||= key.to_a.join("_")

      database[:"system.indexes"].insert(spec)
    end

    # Drop an index, or all indexes.
    #
    # @param [Hash] key the index's key
    # @return [Boolean] whether the indexes were dropped.
    #
    # @example Drop all indexes
    #   session[:users].indexes.count # => 3
    #   # Does not drop the _id index
    #   session[:users].indexes.drop
    #   session[:users].indexes.count # => 1
    #
    # @example Drop a particular index
    #   session[:users].indexes.drop(name: 1)
    #   session[:users].indexes[name: 1] # => nil
    def drop(key = nil)
      if key
        index = self[key] or return false
        name = index["name"]
      else
        name = "*"
      end

      result = database.command deleteIndexes: collection_name, index: name
      result["ok"] == 1
    end

    # @yield [Hash] each index for the collection.
    def each(&block)
      database[:"system.indexes"].find(ns: namespace).each(&block)
    end

  end
end
