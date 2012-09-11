module Moped
  module Protocol

    # The Protocol class representing messages received from a mongo
    # connection.
    #
    # @example
    #   socket = TCPSocket.new "127.0.0.1", 27017
    #   command = Moped::Protocol::Command.new "admin", buildinfo: 1
    #   socket.write command.serialize
    #   reply = Moped::Protocol::Reply.deserialize(socket)
    #   reply.documents[0]["version"] # => "2.0.0"
    class Reply
      include Message

      UNAUTHORIZED = 10057

      # @attribute
      # @return [Number] the length of the message
      int32 :length

      # @attribute
      # @return [Number] the request id of the message
      int32 :request_id

      # @attribute
      # @return [Number] the id that generated the message
      int32 :response_to

      # @attribute
      # @return [Number] the operation code of this message (always 1)
      int32 :op_code

      # @attribute
      # @return [Array<Symbol>] the flags for this reply
      flags    :flags, cursor_not_found:  2 ** 0,
                       query_failure:     2 ** 1,
                       await_capable:     2 ** 3

      # @attribute
      # @return [Number] the id of the cursor on the server
      int64    :cursor_id

      # @attribute
      # @return [Number] the starting position within the cursor
      int32    :offset

      # @attribute
      # @return [Number] the number of documents returned
      int32    :count

      # @attribute
      # @return [Array] the returned documents
      document :documents, type: :array

      finalize

      def cursor_not_found?
        flags.include?(:cursor_not_found)
      end

      def query_failed?
        flags.include?(:query_failure)
      end

      def unauthorized?
        documents.first["code"] == UNAUTHORIZED
      end

      class << self

        # Consumes a buffer, returning the deserialized Reply message.
        #
        # @example
        #   socket = TCPSocket.new "localhost", 27017
        #   socket.write Moped::Protocol::Command.new(:admin, ismaster: 1).serialize
        #   reply = Moped::Protocol::Reply.deserialize(socket)
        #   reply.documents[0]['ismaster'] # => 1
        #
        # @param [#read] buffer an IO or IO-like resource to deserialize the
        # reply from.
        # @return [Reply] the deserialized reply
        def deserialize(buffer)
          reply = allocate
          fields.each do |field|
            reply.__send__ :"deserialize_#{field}", buffer
          end
          reply
        end
      end

      private

      def deserialize_documents(buffer)
        documents = []

        count.times do
          documents << BSON::Document.deserialize(buffer)
        end

        @documents = documents
      end

    end
  end
end
