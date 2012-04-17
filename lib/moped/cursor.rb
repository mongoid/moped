module Moped

  # @api private
  class Cursor
    attr_reader :session

    attr_reader :query_op
    attr_reader :get_more_op
    attr_reader :kill_cursor_op

    def initialize(session, query_operation)
      @session = session

      @database    = query_operation.database
      @collection  = query_operation.collection
      @selector    = query_operation.selector

      @cursor_id = 0
      @limit = query_operation.limit
      @limited = @limit > 0

      @options = {
        request_id: query_operation.request_id,
        flags: query_operation.flags,
        limit: query_operation.limit,
        skip: query_operation.skip,
        fields: query_operation.fields
      }
    end

    def each
      documents = load
      documents.each { |doc| yield doc }

      while more?
        return kill if limited? && @limit <= 0

        documents = get_more
        documents.each { |doc| yield doc }
      end
    end

    def load
      consistency = session.consistency
      @options[:flags] |= [:slave_ok] if consistency == :eventual

      reply, @node = session.context.with_node do |node|
        [node.query(@database, @collection, @selector, @options), node]
      end

      @limit -= reply.count if limited?
      @cursor_id = reply.cursor_id

      reply.documents
    end

    def limited?
      @limited
    end

    def more?
      @cursor_id != 0
    end

    def get_more
      reply = @node.get_more @database, @collection, @cursor_id, @limit

      @limit -= reply.count if limited?
      @cursor_id = reply.cursor_id

      reply.documents
    end

    def kill
      @node.kill_cursors [@cursor_id]
    end
  end

end
