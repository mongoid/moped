module Moped
  module Protocol

    # The Protocol class for retrieving more documents from a cursor.
    #
    # @since 1.0.0
    class GetMore
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

      int32 :reserved # reserved for future use

      # @attribute
      # @return [String] the namespaced collection name
      cstring :full_collection_name

      # @attribute
      # @return [Number] the number of documents to return
      int32 :limit

      # @attribute
      # @return [Number] the id of the cursor to get more documents from
      int64 :cursor_id

      finalize

      # @!attribute collection
      #   @return [ String ] The collection to query.
      # @!attribute database
      #   @return [ String ] The database to query
      attr_reader :collection, :database

      # Determine if the provided reply message is a failure with respect to a
      # get more operation.
      #
      # @example Is the reply a query failure?
      #   get_more.failure?(reply)
      #
      # @param [ Reply ] reply The reply to the get more.
      #
      # @return [ true, false ] If the reply is a failure.
      #
      # @since 2.0.0
      def failure?(reply)
        reply.cursor_not_found? || reply.query_failure?
      end

      # Get the exception specific to a failure of this particular operation.
      #
      # @example Get the failure exception.
      #   get_more.failure_exception(document)
      #
      # @param [ Moped::Protocol::Reply ] reply The reply from the database.
      #
      # @return [ Moped::Errors::CursorNotFound ] The failure exception.
      #
      # @since 2.0.0
      def failure_exception(reply)
        if reply.cursor_not_found?
          Errors::CursorNotFound.new(self, cursor_id)
        else
          Errors::QueryFailure.new(self, reply.documents.first)
        end
      end

      # Create a new GetMore command. The database and collection arguments
      # are joined together to set the full_collection_name.
      #
      # @example Get more results using database default limit.
      #   GetMore.new("moped", "people", 29301021, 0)
      #
      # @example Get more results using custom limit.
      #   GetMore.new("moped", "people", 29301021, 10)
      #
      # @example Get more with a request id.
      #   GetMore.new("moped", "people", 29301021, 10, request_id: 123)
      #
      # @param [ String ] database The database name.
      # @param [ String ] collection The collection name.
      # @param [ Integer ] cursor_id The id of the cursor.
      # @param [ Integer ] limit The number of documents to limit.
      # @param [ Hash ] options The get more options.
      #
      # @option options [ Integer ] :request_id The operation's request id.
      #
      # @since 1.0.0
      def initialize(database, collection, cursor_id, limit, options = {})
        @database = database
        @collection = collection
        @full_collection_name = "#{database}.#{collection}"
        @cursor_id = cursor_id
        @limit = limit
        @request_id = options[:request_id]
      end

      # Provide the value that will be logged when the get more runs.
      #
      # @example Provide the log inspection.
      #   get_more.log_inspect
      #
      # @return [ String ] The string value for logging.
      #
      # @since 1.0.0
      def log_inspect
        type = "GET_MORE"
        "%-12s database=%s collection=%s limit=%s cursor_id=%s" % [type, database, collection, limit, cursor_id]
      end

      undef op_code

      # Get the code for a get more operation.
      #
      # @example Get the operation code.
      #   get_more.op_code
      #
      # @return [ Integer ] OP_GETMORE operation code (2005).
      #
      # @since 1.0.0
      def op_code
        2005
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
      #   get_more.results(reply)
      #
      # @param [ Moped::Protocol::Reply ] reply The reply from the database.
      #
      # @return [ Moped::Protocol::Reply ] The reply.
      #
      # @since 2.0.0
      def results(reply)
        reply
      end
    end
  end
end
