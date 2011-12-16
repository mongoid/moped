module Moped
  class Socket

    # Thread-safe hash for adding, removing, and retrieving callbacks.
    class Callbacks < Hash
      def initialize
        @mutex = Mutex.new
      end

      def []=(key, value)
        @mutex.synchronize { super }
      end

      def [](key)
        @mutex.synchronize { super }
      end

      def delete(key)
        @mutex.synchronize { super }
      end
    end

    # Thread-safe atomic integer.
    class RequestId
      def initialize
        @mutex = Mutex.new
        @id = 0
      end

      def next
        @mutex.synchronize { @id += 1 }
      end
    end

    attr_reader :connection
    attr_reader :callbacks

    def initialize(server, connection)
      @mutex = Mutex.new

      @server = server
      @connection = connection

      @request_id = RequestId.new
      @callbacks = Callbacks.new

      start_read_loop
    end

    # Execute the operation on the connection. Pass a callback if you're
    # interested in the results.
    def execute(op, &callback)
      request_id = @request_id.next
      @callbacks[request_id] = callback if callback

      op.request_id = request_id
      buf = op.serialize

      @mutex.synchronize do
        connection.write buf
      end
    end

    # Executes a simple (one result) query and returns the first document.
    #
    # @return [Hash] the first document in a result set.
    def simple_query(query)
      queue = Queue.new

      execute(query) do |error, reply, num, doc|
        queue.push [error, doc]
      end

      err, doc = queue.pop

      raise err if err

      doc
    end

    # @return [Boolean] whether the socket is still alive
    def dead?
      !!@dead
    end

    # Shut down the run loop and send exception to all registered callbacks.
    def kill(exception)
      @mutex.synchronize do
        return if @dead

        @dead = true
        @connection.close unless @connection.closed?

        @callbacks.each do |id, callback|
          callback[exception]
        end
      end
    end

    def receive(connection)
      reply = Crutches::Protocol::Reply.allocate
      reply.deserialize_length connection
      reply.deserialize_request_id connection
      reply.deserialize_response_to connection
      reply.deserialize_op_code connection

      if reply.op_code != 1
        raise "op-code != 1"
      end

      reply.deserialize_flags connection
      reply.deserialize_cursor_id connection
      reply.deserialize_offset connection
      reply.deserialize_count connection

      # Safely get the callback for this message.
      callback = @callbacks[reply.response_to]

      if callback && reply.count == 0
        # No documents. Tell the callback.
        callback[nil, reply, -1, nil]
      else
        # Consume each document and send it to the callback.
        reply.count.times do |i|
          document = Crutches::BSON::Document.deserialize(connection)

          if callback
            callback[nil, reply, i, document]
          end
        end
      end

      if callback
        # Now remove the callback.
        @callbacks.delete(reply.response_to)
      end
    end

    def read_loop
      connection = self.connection

      loop do
        receive(connection)
      end
    rescue
      kill $!
    end

    private

    def next_request_id
      @request_id += 1
    end

    def start_read_loop
      @read_loop = Thread.new { read_loop }
    end

  end
end
