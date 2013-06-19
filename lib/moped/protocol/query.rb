module Moped
  module Protocol

    # The Protocol class for querying a collection.
    #
    # @since 1.0.0
    class Query
      include Message

      # @!attribute length
      #   @return [ Integer ] the length of the message
      int32 :length

      # @!attribute request_id
      #   @return [ Integer ] the request id of the message
      int32 :request_id

      int32 :response_to

      # @!attribute op_code
      #   @return [ Integer ] the operation code of this message
      int32 :op_code

      # @!attribute
      # The flags for the query. Supported flags are: +:tailable+, +:slave_ok+,
      # +:no_cursor_timeout+, +:await_data+, +:exhaust+.
      #
      # @param  [ Array ] flags the flags for this message
      # @return [ Array ] the flags for this message
      flags :flags, tailable:          2 ** 1,
                    slave_ok:          2 ** 2,
                    no_cursor_timeout: 2 ** 4,
                    await_data:        2 ** 5,
                    exhaust:           2 ** 6

      # @!attribute full_collection_name
      #   @return [ String ] the namespaced collection name
      cstring :full_collection_name

      # @!attribute skip
      #   @return [ Integer ] the number of documents to skip
      int32 :skip

      # @!attribute limit
      #   @return [ Integer ] the number of documents to return
      int32 :limit

      # @!attribute selector
      #   @return [ Hash ] the selector for this query
      document :selector

      # @!attribute fields
      #   @return [ Hash, nil ] the fields to include in the reply
      document :fields, :optional => true

      finalize

      # @!attribute collection
      #   @return [ String ] The collection to query.
      # @!attribute database
      #   @return [ String ] The database to query
      attr_reader :collection, :database

      # @!attribute batch_size
      #   @return [ Integer ] The batch size of the results.
      attr_accessor :batch_size

      # Get the basic selector.
      #
      # @example Get the basic selector.
      #   query.basic_selector
      #
      # @note Sometimes, like in cases of deletion we need this since MongoDB
      #   does not understand $query in operations like DELETE.
      #
      # @return [ Hash ] The basic selector.
      #
      # @since 2.0.0
      def basic_selector
        selector["$query"] || selector
      end

      # Get the exception specific to a failure of this particular operation.
      #
      # @example Get the failure exception.
      #   query.failure_exception(document)
      #
      # @param [ Moped::Protocol::Reply ] reply The reply from the database.
      #
      # @return [ Moped::Errors::QueryFailure ] The failure exception.
      #
      # @since 2.0.0
      def failure_exception(reply)
        Errors::QueryFailure.new(self, reply.documents.first)
      end

      # Determine if the provided reply message is a failure with respect to a
      # query.
      #
      # @example Is the reply a query failure?
      #   query.failure?(reply)
      #
      # @param [ Reply ] reply The reply to the query.
      #
      # @return [ true, false ] If the reply is a failure.
      #
      # @since 2.0.0
      def failure?(reply)
        reply.query_failure?
      end

      # Set the option on the query to not timeout the cursor.
      #
      # @example Set the no timeout option.
      #   query.no_timeout = true
      #
      # @param [ true, false ] enable Whether to enable the no timeout option.
      #
      # @since 1.3.0
      def no_timeout=(enable)
        @flags |= [:no_cursor_timeout] if enable
      end

      # Instantiate a new query operation.
      #
      # @example Find all users named John.
      #   Query.new("moped", "users", { name: "John" })
      #
      # @example Find all users named John skipping 5 and returning 10.
      #   Query.new("moped", "users", { name: "John" }, skip: 5, limit: 10)
      #
      # @example Find all users on slave node.
      #   Query.new("moped", "users", {}, flags: [ :slave_ok ])
      #
      # @example Find all user ids.
      #   Query.new("moped", "users", {}, fields: { _id: 1 })
      #
      # @param [ String, Symbol ] database The database to query.
      # @param [ String, Symbol ] collection The collection to query.
      # @param [ Hash ] selector The query selector.
      # @param [ Hash ] options The additional query options.
      #
      # @option options [ Integer ] :request_id The operation's request id.
      # @option options [ Integer ] :skip The number of documents to skip.
      # @option options [ Integer ] :limit The number of documents to return.
      # @option options [ Hash ] :fields The limited fields to return.
      # @option options [ Array ] :flags The flags for querying. Supported flags
      #   are: :tailable, :slave_ok, :no_cursor_timeout, :await_data, :exhaust.
      #
      # @since 1.0.0
      def initialize(database, collection, selector, options = {})
        @database = database
        @collection = collection
        @full_collection_name = "#{database}.#{collection}"
        @selector = selector
        @request_id = options[:request_id]
        @flags = options[:flags] || []
        @limit = options[:limit]
        @skip = options[:skip]
        @fields = options[:fields]
        @batch_size = options[:batch_size]
      end

      # Provide the value that will be logged when the query runs.
      #
      # @example Provide the log inspection.
      #   query.log_inspect
      #
      # @return [ String ] The string value for logging.
      #
      # @since 1.0.0
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

      undef op_code

      # Get the code for a query operation.
      #
      # @example Get the operation code.
      #   query.op_code
      #
      # @return [ Integer ] OP_QUERY operation code (2004).
      #
      # @since 1.0.0
      def op_code
        2004
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

      # Take the provided reply and return the expected results to api
      # consumers.
      #
      # @example Get the expected results of the reply.
      #   query.results(reply)
      #
      # @param [ Moped::Protocol::Reply ] reply The reply from the database.
      #
      # @return [ Moped::Protocol::Reply ] The reply.
      #
      # @since 2.0.0
      def results(reply)
        reply
      end

      private

      # Duplicate the attributes in the query that need to be.
      #
      # @api private
      #
      # @example Clone the query.
      #   query.clone
      #
      # @param [ Query ] The query that was cloned from.
      #
      # @since 2.0.0
      def initialize_copy(_)
        @selector = selector.dup
        @flags = flags.dup
        @fields = fields.dup if fields
      end
    end
  end
end
