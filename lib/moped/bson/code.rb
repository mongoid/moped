module Moped
  module BSON
    class Code

      attr_reader :code, :scope

      def initialize(code, scope=nil)
        @code = code
        @scope = scope
      end

      def scoped?
        !!scope
      end

      def ==(other)
        BSON::Code === other && code == other.code && scope == other.scope
      end
      alias eql? ==

      def hash
        [code, scope].hash
      end

      class << self
        def __bson_load__(io)
          code = io.read(*io.read(4).unpack(INT32_PACK)).from_utf8_binary.chop!
          new code
        end
      end

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

    end
  end
end
