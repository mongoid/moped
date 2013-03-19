module Moped

  # Defines behaviour around indexes.
  class Indexes
    include Enumerable

    # @attribute [r] collection_name The collection name.
    # @attribute [r] database The database.
    # @attribute [r] namespace The index namespace.
    attr_reader :collection_name, :database, :namespace

    # Retrive an index by its definition.
    #
    # @example Get the index.
    #   session[:users].indexes[id: 1]
    #   # => {"v"=>1, "key"=>{"_id"=>1}, "ns"=>"moped_test.users", "name"=>"_id_" }
    #
    # @param [ Hash ] key The index definition.
    #
    # @return [ Hash, nil ] The index with the provided key, or nil.
    #
    # @since 1.0.0
    def [](key)
      database[:"system.indexes"].find(ns: namespace, key: key).one
    end

    # Create an index unless it already exists.
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
    #
    # @param [ Hash ] key The index spec.
    # @param [ Hash ] options The options for the index.
    #
    # @return [ Hash ] The index spec.
    #
    # @see http://www.mongodb.org/display/DOCS/Indexes#Indexes-CreationOptions
    #
    # @since 1.0.0
    def create(key, options = {})
      spec = options.merge(ns: namespace, key: key)
      spec[:name] ||= key.to_a.join("_")

      database.session.with(write: { w: 1 }) do |_s|
        _s[:"system.indexes"].insert(spec)
      end
    end

    # Drop an index, or all indexes.
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
    #
    # @param [ Hash ] key The index's key.
    #
    # @return [ Boolean ] Whether the indexes were dropped.
    #
    # @since 1.0.0
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

    # Iterate over each of the indexes for the collection.
    #
    # @example Iterate over the indexes.
    #   indexes.each do |spec|
    #     #...
    #   end
    #
    # @return [ Enumerator ] The enumerator.
    #
    # @since 1.0.0
    #
    # @yield [ Hash ] Each index for the collection.
    def each(&block)
      database[:"system.indexes"].find(ns: namespace).each(&block)
    end

    # Initialize the indexes.
    #
    # @example Create the new indexes.
    #   Indexes.new(database, :artists)
    #
    # @param [ Database ] database The database.
    # @param [ String, Symbol ] collection_name The name of the collection.
    #
    # @since 1.0.0
    def initialize(database, collection_name)
      @database, @collection_name = database, collection_name
      @namespace = "#{database.name}.#{collection_name}"
    end
  end
end
