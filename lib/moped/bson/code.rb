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
          code = io.read(*io.read(4).unpack(INT32_PACK)).chop!.force_encoding('utf-8')
          new code
        end
      end

      def __bson_dump__(io, key)
        if scoped?
          io << Types::CODE_WITH_SCOPE
          io << key
          io << NULL_BYTE

          code_start = io.length

          io << START_LENGTH
          io << [code.bytesize+1].pack(INT32_PACK)
          io << code.encode('utf-8').force_encoding('binary')
          io << NULL_BYTE

          scope.__bson_dump__(io)

          io[code_start, 4] = [io.bytesize - code_start].pack(INT32_PACK)

        else
          io << Types::CODE
          io << key
          io << NULL_BYTE
          io << [code.bytesize+1].pack(INT32_PACK)
          io << code.encode('utf-8').force_encoding('binary')
          io << NULL_BYTE
        end
      end

    end
  end
end
