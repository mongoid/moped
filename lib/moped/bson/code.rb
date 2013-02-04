module Moped
  module BSON

    # Object representation of a javascript expression.
    class Code

      attr_reader :code, :scope

      # Dump the code into it's raw bytes.
      #
      # @example Dump the code to raw bytes.
      #   code.__bson_dump__(string, "expression")
      #
      # @param [ String ] io The raw bytes to write to.
      # @param [ String ] key The field name.
      #
      # @since 1.0.0
      def __bson_dump__(io, key)
        if scoped?
          io << Types::CODE_WITH_SCOPE
          io << key.to_bson_cstring
          code_start = io.bytesize
          io << START_LENGTH
          data = code.to_utf8_binary
          io << [data.bytesize+1].pack(INT32_PACK)
          io << data
          io << NULL_BYTE
          scope.__bson_dump__(io)
          io[code_start, 4] = [io.bytesize - code_start].pack(INT32_PACK)
        else
          io << Types::CODE
          io << key.to_bson_cstring
          data = code.to_utf8_binary
          io << [data.bytesize+1].pack(INT32_PACK)
          io << data
          io << NULL_BYTE
        end
      end

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
      def ==(other)
        BSON::Code === other && code == other.code && scope == other.scope
      end
      alias :eql? :==

      # Gets the hash code for the object.
      #
      # @example Get the hash code.
      #   object.hash
      #
      # @return [ Fixnum ] The hash code.
      #
      # @since 1.0.0
      def hash
        [code, scope].hash
      end

      # Create the new code type.
      #
      # @example Create the new code.
      #   Moped::BSON::Code.new("this.value = param", param: "test")
      #
      # @param [ String ] code The javascript code.
      # @param [ Object ] scope The scoped variables and values.
      #
      # @since 1.0.0
      def initialize(code, scope = nil)
        @code = code
        @scope = scope
      end

      # Is the code scoped?
      #
      # @example Is the code scoped?
      #   code.scoped?
      #
      # @return [ true, false ] If the code is scoped.
      #
      # @since 1.0.0
      def scoped?
        !!scope
      end

      class << self

        # Load the BSON from the raw data to a code.
        #
        # @example Load the raw data.
        #   Moped::BSON::Code.__bson_load__(data)
        #
        # @param [ String ] io The raw bytes of data.
        #
        # @return [ Code ] The code object.
        #
        # @since 1.0.0
        def __bson_load__(io)
          code = io.read(*io.read(4).unpack(INT32_PACK)).from_utf8_binary.chop!
          new(code)
        end
      end
    end
  end
end
