module Moped
  module Protocol

    # The Protocol class for deleting documents from a collection.
    #
    # @example Delete all people named John
    #   delete = Delete.new "moped", "people", { name: "John" }
    #
    # @example Delete the first person named John
    #   delete = Delete.new "moped", "people", { name: "John" },
    #     flags: [:remove_first]
    #
    # @example Setting the request id
    #   delete = Delete.new "moped", "people", { name: "John" },
    #     request_id: 123
    class Delete
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
      # @return [String] the full collection name
      cstring  :full_collection_name

      # @attribute
      # @param [Array] the flags for the message
      # @return [Array] the flags for the message
      flags    :flags, remove_first: 2 ** 0

      # @attribute
      # @return [Hash] the query to use when deleting documents
      document :selector

      finalize

      # @return [String, Symbol] the database to delete from
      attr_reader :database

      # @return [String, Symbol] the collection to delete from
      attr_reader :collection

      # Create a new delete command. The +database+ and +collection+ arguments
      # are joined together to set the +full_collection_name+.
      #
      # @example
      #   Delete.new "moped", "users", { condition: true },
      #     flags: [:remove_first],
      #     request_id: 123
      #
      # @param [String, Symbol] database the database to delete from
      # @param [String, Symbol] collection the collection to delete from
      # @param [Hash] selector the selector for which documents to delete
      # @param [Hash] options additional options
      # @option options [Number] :request_id the command's request id
      # @option options [Array] :flags the flags for insertion. Supported
      #   flags: +:remove_first+
      def initialize(database, collection, selector, options = {})
        @database   = database
        @collection = collection

        @full_collection_name = "#{database}.#{collection}"
        @selector             = selector
        @request_id           = options[:request_id]
        @flags                = options[:flags]
      end

      undef op_code
      # @return [Number] OP_DELETE operation code (2006)
      def op_code
        2006
      end

      def log_inspect
        type = "DELETE"

        "%-12s database=%s collection=%s selector=%s flags=%s" % [type, database, collection, selector.inspect, flags.inspect]
      end

      private

      # Duplicate the attributes in the delete that need to be.
      #
      # @api private
      #
      # @example Clone the delete.
      #   delete.clone
      #
      # @param [ Delete ] The delete that was cloned from.
      #
      # @since 2.0.0
      def initialize_copy(_)
        @selector = selector.dup
        @flags = flags.dup
      end
    end
  end
end
