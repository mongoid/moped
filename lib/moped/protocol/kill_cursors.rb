module Moped
  module Protocol

    # The Protocol class for killing active cursors.
    #
    # @example
    #   command = KillCursors.new [123, 124, 125]
    #
    # @example Setting the request id
    #   command = KillCursors.new [123, 124, 125], request_id: 456
    class KillCursors
      include Message

      # @attribute
      # @return [Number] the length of the message
      int32 :length

      # @attribute
      # @return [Number] the request id of the message
      int32 :request_id

      int32 :response_to

      # @attribute
      # @return [Number] the operation code of this message
      int32 :op_code

      int32    :reserved # reserved for future use

      # @attribute
      # @return [Number] the number of cursor ids
      int32    :number_of_cursor_ids

      # @attribute
      # @return [Array] the cursor ids to kill
      int64    :cursor_ids, type: :array

      finalize

      undef op_code
      # @return [Number] OP_KILL_CURSORS operation code (2007)
      def op_code
        2007
      end

      # Create a new command to kill cursors.
      #
      # @param [Array] cursor_ids an array of cursor ids to kill
      # @param [Hash] options additional options
      # @option options [Number] :request_id the command's request id
      def initialize(cursor_ids, options = {})
        @cursor_ids           = cursor_ids
        @number_of_cursor_ids = cursor_ids.length
        @request_id           = options[:request_id]
      end

      def log_inspect
        type = "KILL_CURSORS"

        "%-12s cursor_ids=%s" % [type, cursor_ids.inspect]
      end
    end
  end
end
