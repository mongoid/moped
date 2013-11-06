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

      # Unauthorized assertion errors.
      UNAUTHORIZED = [ 10057, 16550 ]

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

      # Is the reply the result of a command failure?
      #
      # @example Did the command fail?
      #   reply.command_failure?
      #
      # @note This is when ok is not 1, or "err" or "errmsg" are present.
      #
      # @return [ true, false ] If the command failed.
      #
      # @since 1.2.10
      def command_failure?
        result = documents.first
        (result["ok"] != 1.0 && result["ok"] != true) || error?
      end

      # Was the provided cursor id not found on the server?
      #
      # @example Is the cursor not on the server?
      #   reply.cursor_not_found?
      #
      # @return [ true, false ] If the cursor went missing.
      #
      # @since 1.2.0
      def cursor_not_found?
        flags.include?(:cursor_not_found)
      end

      # Check if the first returned document in the reply is an error result.
      #
      # @example Is the first document in the reply an error?
      #   reply.error?
      #
      # @return [ true, false ] If the first document is an error.
      #
      # @since 2.0.0
      def error?
        result = documents.first
        result && error_message(result)
      end

      # Did the query fail on the server?
      #
      # @example Did the query fail?
      #   reply.query_failure?
      #
      # @return [ true, false ] If the query failed.
      #
      # @since 1.2.0
      def query_failure?
        flags.include?(:query_failure) || error?
      end

      # Is the reply an error message that we are not authorized for the query
      # or command?
      #
      # @example Was the query unauthorized.
      #   reply.unauthorized?
      #
      # @note So far this can be a "code" of 10057 in the error message or an
      #   "assertionCode" of 10057.
      #
      # @return [ true, false ] If we had an authorization error.
      #
      # @since 1.2.10
      def unauthorized?
        result = documents[0]
        return false if result.nil?
        err = error_message(result)
        UNAUTHORIZED.include?(result["code"]) ||
          UNAUTHORIZED.include?(result["assertionCode"]) ||
          (err && (err =~ /unauthorized/ || err =~ /not authorized/))
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
          documents << ::BSON::Document.from_bson(buffer)
        end
        @documents = documents
      end

      def error_message(result)
        result["err"] || result["errmsg"] || result["$err"]
      end
    end
  end
end
