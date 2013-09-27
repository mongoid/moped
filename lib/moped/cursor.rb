module Moped

  # Contains logic for cursor behaviour.
  #
  # @api private
  class Cursor
    include Readable
    include Enumerable

    # @attribute [r] get_more_op The get more message.
    # @attribute [r] kill_cursor_op The kill cursor message.
    # @attribute [r] query_op The query message.
    # @attribute [r] session The session.
    attr_reader :get_more_op, :kill_cursor_op, :query_op, :session

    # Iterate over the results of the query.
    #
    # @example Iterate over the results.
    #   cursor.each do |doc|
    #     #...
    #   end
    #
    # @return [ Enumerator ] The cursor enum.
    #
    # @since 1.0.0
    def each
      documents = load_docs
      documents.each { |doc| yield doc }
      while more?
        return kill if limited? && @limit <= 0
        documents = get_more
        documents.each { |doc| yield doc }
      end
    end

    # Get more documents from the database for the cursor. Executes a get more
    # command.
    #
    # @example Get more docs.
    #   cursor.get_more
    #
    # @return [ Array<Hash> ] The next batch of documents.
    #
    # @since 1.0.0
    def get_more
      reply = @node.get_more @database, @collection, @cursor_id, request_limit
      @limit -= reply.count if limited?
      @cursor_id = reply.cursor_id
      reply.documents
    end

    # Determine the request limit for the query
    #
    # @example What is the cursor request_limit
    #   cursor.request_limit
    #
    # @return [ Integer ]
    #
    # @since 1.0.0

    def request_limit
      if limited?
        @batch_size < @limit ? @batch_size : @limit
      else
        @batch_size
      end
    end

    # Initialize the new cursor.
    #
    # @example Create the new cursor.
    #   Cursor.new(session, message)
    #
    # @param [ Session ] session The session.
    # @param [ Message ] query_operation The query message.
    #
    # @since 1.0.0
    def initialize(session, query_operation)
      @session = session

      @database    = query_operation.database
      @collection  = query_operation.collection
      @selector    = query_operation.selector

      @cursor_id = 0
      @limit = query_operation.limit
      @limited = @limit > 0
      @batch_size = query_operation.batch_size || @limit

      @options = {
        request_id: query_operation.request_id,
        flags: query_operation.flags,
        limit: query_operation.limit,
        skip: query_operation.skip,
        fields: query_operation.fields,
      }
    end

    # Kill the cursor.
    #
    # @example Kill the cursor.
    #   cursor.kill
    #
    # @return [ Object ] The result of the kill cursors command.
    #
    # @since 1.0.0
    def kill
      @node.kill_cursors([ @cursor_id ])
    end

    # Does the cursor have a limit provided in the query?
    #
    # @example Is the cursor limited?
    #   cursor.limited?
    #
    # @return [ true, false ] If a limit has been provided over zero.
    #
    # @since 1.0.0
    def limited?
      @limited
    end

    # Load the documents from the database.
    #
    # @example Load the documents.
    #   cursor.load_docs
    #
    # @return [ Array<Hash> ] The documents.
    #
    # @since 1.0.0
    def load_docs
      @options[:flags] |= [:no_cursor_timeout] if @options[:no_timeout]
      options = @options.clone
      options[:limit] = request_limit

      reply, @node = read_preference.with_node(session.cluster) do |node|
        [ node.query(@database, @collection, @selector, query_options(options)), node ]
      end

      @limit -= reply.count if limited?
      @cursor_id = reply.cursor_id
      reply.documents
    end

    # Are there more documents to be returned from the database?
    #
    # @example Are there more documents?
    #   cursor.more?
    #
    # @return [ true, false ] If there are more documents to load.
    #
    # @since 1.0.0
    def more?
      @cursor_id != 0
    end
  end
end
