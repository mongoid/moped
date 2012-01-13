module Moped

  # @api private
  class Cursor
    attr_reader :session

    attr_reader :query_op
    attr_reader :get_more_op
    attr_reader :kill_cursor_op

    def initialize(session, query_operation)
      @session = session
      @query_op = query_operation.dup

      @get_more_op = Protocol::GetMore.new(
        @query_op.database,
        @query_op.collection,
        0,
        @query_op.limit
      )

      @kill_cursor_op = Protocol::KillCursors.new([0])
    end

    def each
      documents = query @query_op
      documents.each { |doc| yield doc }

      while more?
        return kill if limited? && @get_more_op.limit <= 0

        documents = query @get_more_op
        documents.each { |doc| yield doc }
      end
    end

    def query(operation)
      reply = session.query operation

      @get_more_op.limit -= reply.count if limited?
      @get_more_op.cursor_id = reply.cursor_id
      @kill_cursor_op.cursor_ids = [reply.cursor_id]

      reply.documents
    end

    def limited?
      @query_op.limit > 0
    end

    def more?
      @get_more_op.cursor_id != 0
    end

    def kill
      session.execute kill_cursor_op
    end
  end

end
