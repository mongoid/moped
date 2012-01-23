module Support
  class MockConnection

    attr_reader :pending_replies

    def initialize
      @connected = true
      @buffer = StringIO.new
      @pending_replies = []
    end

    def write(*args)

    end

    def read(*args)
      while documents = pending_replies.shift
        reply = Moped::Protocol::Reply.allocate.tap do |reply|
          documents = [documents] unless documents.is_a? Array
          reply.documents = documents
          reply.count = documents.length
        end

        reply.serialize(@buffer.string)
      end

      @buffer.read(*args)
    end

    def closed?
      !@connected
    end

    def close
      @connected = false
    end

  end
end
