module Moped
  module Protocol
    # The Protocol class for querying a collection.
    #
    # @example Find all users named John
    #   Query.new "moped", "users", { name: "John" }
    #
    # @example Find all users named John skipping 5 and returning 10
    #   Query.new "moped", "users", { name: "John" },
    #     skip: 5, limit: 10
    #
    # @example Find all users on slave node
    #   Query.new "moped", "users", {}, flags: [:slave_ok]
    #
    # @example Find all user ids
    #   Query.new "moped", "users", {}, fields: { _id: 1 }
    #
    class Query
      include Message

      # @attribute
      # @return [Number] the length of the message
      int32 :length

      # @attribute
      # @return [Number] the request id of the message
      int32 :request_id

      int32 :response_to

      # @attribute
      # @return [Number] the operation code of this message
      int32 :op_code

      # @attribute
      # The flags for the query. Supported flags are: +:tailable+, +:slave_ok+,
      # +:no_cursor_timeout+, +:await_data+, +:exhaust+.
      #
      # @param  [Array] flags the flags for this message
      # @return [Array] the flags for this message
      flags    :flags, tailable:          2 ** 1,
                       slave_ok:          2 ** 2,
                       no_cursor_timeout: 2 ** 4,
                       await_data:        2 ** 5,
                       exhaust:           2 ** 6

      # @attribute
      # @return [String] the namespaced collection name
      cstring  :full_collection_name

      # @attribute
      # @return [Number] the number of documents to skip
      int32    :skip

      # @attribute
      # @return [Number] the number of documents to return
      int32    :limit

      # @attribute
      # @return [Hash] the selector for this query
      document :selector

      # @attribute
      # @return [Hash, nil] the fields to include in the reply
      document :fields, :optional => true

      finalize

      undef op_code
      # @return [Number] OP_QUERY operation code (2004)
      def op_code
        2004
      end

      # @return [String, Symbol] the database to query
      attr_reader :database

      # @return [String, Symbol] the collection to query
      attr_reader :collection

      attr_accessor :batch_size

      def no_timeout=(enable)
        @flags |= [:no_cursor_timeout] if enable
      end

      # Create a new query command.
      #
      # @example
      #   Query.new "moped", "users", { name: "John" },
      #     skip: 5,
      #     limit: 10,
      #     request_id: 12930,
      #     fields: { _id: -1, name: 1 }
      #
      # @param [String, Symbol] database the database to insert into
      # @param [String, Symbol] collection the collection to insert into
      # @param [Hash] selector the query
      # @param [Hash] options additional options
      # @option options [Number] :request_id the command's request id
      # @option options [Number] :skip the number of documents to skip
      # @option options [Number] :limit the number of documents to return
      # @option options [Hash] :fields the fields to return
      # @option options [Array] :flags the flags for querying. Supported
      #   flags: +:tailable+, +:slave_ok+, +:no_cursor_timeout+, +:await_data+,
      #   +:exhaust+.
      def initialize(database, collection, selector, options = {})
        @database = database
        @collection = collection

        @full_collection_name = "#{database}.#{collection}"
        @selector             = selector
        @request_id           = options[:request_id]
        @flags                = options[:flags] || []
        @limit                = options[:limit]
        @skip                 = options[:skip]
        @fields               = options[:fields]
        @batch_size           = options[:batch_size]
      end

      def log_inspect
        type = "QUERY"
        fields = []
        fields << ["%-12s", type]
        fields << ["database=%s", database]
        fields << ["collection=%s", collection]
        fields << ["selector=%s", selector.inspect]
        fields << ["flags=%s", flags.inspect]
        fields << ["limit=%s", limit.inspect]
        fields << ["skip=%s", skip.inspect]
        fields << ["batch_size=%s", batch_size.inspect]
        fields << ["fields=%s", self.fields.inspect]
        f, v = fields.transpose
        f.join(" ") % v
      end

      # Get the basic selector.
      #
      # @example Get the basic selector.
      #   query.basic_selector
      #
      # @note Sometimes, like in cases of deletion we need this since MongoDB
      # does not understand $query in operations like DELETE.
      #
      # @return [ Hash ] The basic selector.
      #
      # @since 2.0.0
      def basic_selector
        selector["$query"] || selector
      end

      # Receive replies to the message.
      #
      # @example Receive replies.
      #   message.receive_replies(connection)
      #
      # @param [ Connection ] connection The connection.
      #
      # @return [ Protocol::Reply ] The reply.
      #
      # @since 1.0.0
      def receive_replies(connection)
        connection.read
      end
    end
  end
end
