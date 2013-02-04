module Moped
  module BSON

    # Represents the minimum key value in the database.
    class MinKey

      class << self

        # Check equality on the object.
        #
        # @example Check equality.
        #   object == other
        #
        # @param [ Object ] other The object to check against.
        #
        # @return [ true, false ] If the objects are equal.
        #
        # @since 1.0.0
        def ===(other)
          other == self
        end

        # Load the min key from the raw data.
        #
        # @example Load the min key.
        #   Moped::BSON::MinKey.__bson_load("")
        #
        # @param [ String ] io The raw bytes.
        #
        # @return [ Class ] The Moped::BSON::MinKey class.
        #
        # @since 1.0.0
        def __bson_load__(io); self; end

        # Dump the min key to the raw bytes.
        #
        # @example Dump the min key.
        #   Moped::BSON::MinKey.__bson_dump__("", "min")
        #
        # @param [ String ] io The raw bytes to write to.
        # @param [ String ] key The field name.
        #
        # @since 1.0.0
        def __bson_dump__(io, key)
          io << Types::MIN_KEY
          io << key.to_bson_cstring
        end
      end
    end
  end
end
