module Moped

  # @api private
  class Cursor
    attr_reader :socket

    attr_reader :query_op
    attr_reader :get_more_op
    attr_reader :kill_cursor_op

    def initialize(socket, query_operation)
      @socket = socket
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
      documents = execute @query_op
      documents.each { |doc| yield doc }

      while more?
        return kill if limited? && @get_more_op.limit <= 0

        documents = execute @get_more_op
        documents.each { |doc| yield doc }
      end
    end

    def execute(operation)
      reply = socket.execute operation

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
      socket.execute kill_cursor_op
    end
  end

end
