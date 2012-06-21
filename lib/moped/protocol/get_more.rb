module Moped
  module Protocol

    # The Protocol class for retrieving more documents from a cursor.
    #
    # @example Get more results using database default limit
    #   insert = GetMore.new "moped", "people", 29301021, 0
    #
    # @example Get more results using custom limit
    #   insert = Insert.new "moped", "people", 29301021, 10
    #
    # @example Setting the request id
    #   insert = Insert.new "moped", "people", 29301021, 10,
    #     request_id: 123
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

      int32    :reserved # reserved for future use

      # @attribute
      # @return [String] the namespaced collection name
      cstring  :full_collection_name

      # @attribute
      # @return [Number] the number of documents to return
      int32    :limit

      # @attribute
      # @return [Number] the id of the cursor to get more documents from
      int64    :cursor_id

      finalize

      undef op_code
      # @return [Number] OP_GETMORE operation code (2005)
      def op_code
        2005
      end

      # @return [String, Symbol] the database this insert targets
      attr_reader :database

      # @return [String, Symbol] the collection this insert targets
      attr_reader :collection

      # Create a new +GetMore+ command. The +database+ and +collection+ arguments
      # are joined together to set the +full_collection_name+.
      #
      # @example
      #   GetMore.new "moped", "users", 29301021, 10, request_id: 123
      def initialize(database, collection, cursor_id, limit, options = {})
        @database   = database
        @collection = collection

        @full_collection_name = "#{database}.#{collection}"
        @cursor_id            = cursor_id
        @limit                = limit
        @request_id           = options[:request_id]
      end

      def log_inspect
        type = "GET_MORE"
        "%-12s database=%s collection=%s limit=%s cursor_id=%s" % [type, database, collection, limit, cursor_id]
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
