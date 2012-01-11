module Moped
  class Socket

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

    attr_reader :host
    attr_reader :port

    def initialize(host, port)
      @host = host
      @port = port

      @mutex = Mutex.new
      @request_id = RequestId.new
    end

    def connect
      return true if @connected

      @connection = TCPSocket.new host, port
      @connected = true
    end

    # Execute the operation on the connection.
    def execute(op)
      buf = ""

      op.request_id = @request_id.next
      op.serialize buf

      @mutex.lock
      connection.write buf

      if Protocol::Query === op || Protocol::GetMore === op
        length, = connection.read(4).unpack('l<')
        data = connection.read(length - 4)
        @mutex.unlock

        parse_reply length, data
      else
        @mutex.unlock

        true
      end
    end

    def parse_reply(length, data)
      buffer = StringIO.new data

      reply = Protocol::Reply.allocate

      reply.length = length

      reply.request_id,
        reply.response_to,
        reply.op_code,
        reply.flags,
        reply.cursor_id,
        reply.offset,
        reply.count = buffer.read(32).unpack('l4<q<l2<')

      reply.documents = reply.count.times.map do
        BSON::Document.deserialize(buffer)
      end

      reply
    end

    # Executes a simple (one result) query and returns the first document.
    #
    # @return [Hash] the first document in a result set.
    def simple_query(query)
      query = query.dup
      query.limit = -1

      execute(query).documents.first
    end

    # @return [Boolean] whether the socket is dead
    def dead?
      @mutex.synchronize do
        @dead || @connection.closed?
      end
    end

    # Manually closes the connection
    def close
      @mutex.synchronize do
        return if @dead

        @dead = true
        @connection.close unless @connection.closed?
      end
    end

  end
end
