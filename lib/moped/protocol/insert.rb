module Moped
  module Protocol

    # The Protocol class for inserting documents into a collection.
    #
    # @example
    #   insert = Insert.new "moped", "people", [{ name: "John" }]
    #
    # @example Continuing after an error on batch insert
    #   insert = Insert.new "moped", "people",
    #     [{ unique_field: 1 }, { unique_field: 1 }, { unique_field: 2 }],
    #     flags: [:continue_on_error]
    #
    # @example Setting the request id
    #   insert = Insert.new "moped", "people", [{ name: "John" }],
    #     request_id: 123
    class Insert
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

      # @attribute
      # The flags for the query. Supported flags are: +:continue_on_error+.
      #
      # @param  [Array] flags the flags for this message
      # @return [Array] the flags for this message
      flags    :flags, continue_on_error: 2 ** 0

      # @attribute
      # @return [String] the namespaced collection name
      cstring  :full_collection_name

      # @attribute
      # @return [Array<Hash>] the documents to insert
      document :documents, type: :array

      finalize

      undef op_code
      # @return [Number] OP_INSERT operation code (2002)
      def op_code
        2002
      end

      # @return [String, Symbol] the database this insert targets
      attr_reader :database

      # @return [String, Symbol] the collection this insert targets
      attr_reader :collection

      # Create a new insert command. The +database+ and +collection+ arguments
      # are joined together to set the +full_collection_name+.
      #
      # @example
      #   Insert.new "moped", "users", [{ name: "John" }],
      #     flags: [:continue_on_error],
      #     request_id: 123
      #
      # @param [String, Symbol] database the database to insert into
      # @param [String, Symbol] collection the collection to insert into
      # @param [Array<Hash>] documents the documents to insert
      # @param [Hash] options additional options
      # @option options [Number] :request_id the command's request id
      # @option options [Array] :flags the flags for insertion. Supported
      #   flags: +:continue_on_error+
      def initialize(database, collection, documents, options = {})
        @database = database
        @collection = collection

        @full_collection_name = "#{database}.#{collection}"
        @documents            = documents
        @request_id           = options[:request_id]
        @flags                = options[:flags]
      end

      def log_inspect
        type = "INSERT"

        "%-12s database=%s collection=%s documents=%s flags=%s" % [type, database, collection, documents.inspect, flags.inspect]
      end

      private

      # Duplicate the attributes in the insert that need to be.
      #
      # @api private
      #
      # @example Clone the insert.
      #   insert.clone
      #
      # @param [ Insert ] The insert that was cloned from.
      #
      # @since 2.0.0
      def initialize_copy(_)
        @documents = documents.dup
        @flags = flags.dup
      end
    end
  end
end
