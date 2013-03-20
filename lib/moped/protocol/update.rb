module Moped
  module Protocol

    # The Protocol class for updating documents in a collection.
    #
    # @example Rename a user
    #   Update.new "moped", "users", { _id: "123" }, { name: "Bob" }
    #
    # @example Rename all users named John
    #   Update.new "moped", "users", { name: "John" }, { name: "Bob" },
    #     flags: [:multi]
    #
    # @example Upsert
    #   Update.new "moped", "users", { name: "John" }, { name: "John" },
    #     flags: [:upsert]
    #
    # @example Setting the request id
    #   Update.new "moped", "users", {}, { name: "Bob" },
    #     request_id: 123
    class Update
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
      # @return [String] the namespaced collection name
      cstring  :full_collection_name

      # @attribute
      # The flags for the update message. Supported flags are +:upsert+ and
      # +:multi+.
      # @param  [Array] flags the flags for this message
      # @return [Array] the flags for this message
      flags    :flags, upsert: 2 ** 0,
                       multi:  2 ** 1

      # @attribute
      # @return [Hash] the selector for the update
      document :selector

      # @attribute
      # @return [Hash] the updates to apply
      document :update

      finalize

      undef op_code
      # @return [Number] OP_UPDATE operation code (2001)
      def op_code
        2001
      end

      # @return [String, Symbol] the database this insert targets
      attr_reader :database

      # @return [String, Symbol] the collection this insert targets
      attr_reader :collection

      # Create a new update command. The +database+ and +collection+ arguments
      # are joined together to set the +full_collection_name+.
      #
      # @example
      #   Update.new "moped", "users", { name: "John" }, { name: "Bob" },
      #     flags: [:upsert],
      #     request_id: 123
      #
      # @param [String, Symbol] database the database to insert into
      # @param [String, Symbol] collection the collection to insert into
      # @param [Hash] selector the selector
      # @param [Hash] update the update to perform
      # @param [Hash] options additional options
      # @option options [Number] :request_id the command's request id
      # @option options [Array] :flags the flags for insertion. Supported
      #   flags: +:upsert+, +:multi+.
      def initialize(database, collection, selector, update, options = {})
        @database = database
        @collection = collection

        @full_collection_name = "#{database}.#{collection}"
        @selector             = selector
        @update               = update
        @request_id           = options[:request_id]
        @flags                = options[:flags]
      end

      def log_inspect
        type = "UPDATE"

        "%-12s database=%s collection=%s selector=%s update=%s flags=%s" % [type, database, collection,
                                                                            selector.inspect,
                                                                            update.inspect,
                                                                            flags.inspect]
      end

      private

      # Duplicate the attributes in the update that need to be.
      #
      # @api private
      #
      # @example Clone the update.
      #   update.clone
      #
      # @param [ Update ] The update that was cloned from.
      #
      # @since 2.0.0
      def initialize_copy(_)
        @selector = selector.dup
        @update = update.dup
        @flags = flags.dup
      end
    end
  end
end
