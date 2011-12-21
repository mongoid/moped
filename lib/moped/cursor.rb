module Moped

  # @api private
  class Cursor
    attr_reader :socket
    attr_reader :query_op
    attr_reader :get_more_op

    def initialize(socket, query_operation)
      @socket = socket
      @query_op = query_operation.dup

      @get_more_op = Protocol::GetMore.new(
        @query_op.database,
        @query_op.collection,
        0,
        @query_op.limit
      )

      @query_op.callback = @get_more_op.callback = callback

      @cache = Queue.new
    end

    def each
      while document = self.next
        yield document
      end
    end

    def next
      if @pending_docs == nil
        @pending_docs = 1
        socket.execute @query_op
      end

      pending_docs = @pending_docs

      if pending_docs > 0 || @cache.length > 0
        @cache.pop
      elsif @get_more_op.cursor_id != 0
        if @query_op.limit > 0
          if @get_more_op.limit > 0
            @pending_docs += 1

            socket.execute @get_more_op
            self.next
          else
            kill
            nil
          end
        else
          @pending_docs += 1
          socket.execute @get_more_op
          self.next
        end
      end
    end

    def kill
      socket.execute Protocol::KillCursors.new(
        [@get_more_op.cursor_id]
      )
    end

    def callback
      @callback ||= proc do |err, reply, n, doc|
        @pending_docs -= 1

        if n == 0
          @pending_docs += reply.count - 1
          @get_more_op.limit -= reply.count if @query_op.limit > 0
          @get_more_op.cursor_id = reply.cursor_id
        end

        @cache.push doc
      end
    end
  end

end
