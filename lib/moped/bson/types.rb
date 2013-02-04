module Moped
  module BSON

    # Various BSON type behaviour.
    module Types

      class CodeWithScope

        def self.__bson_load__(io)
          io.read 4 # swallow the length
          code = io.read(*io.read(4).unpack(INT32_PACK)).from_utf8_binary.chop!
          scope = BSON::Document.deserialize(io)
          Code.new(code, scope)
        end
      end

      class Integer64

        def self.__bson_load__(io)
          io.read(8).unpack(INT64_PACK)[0]
        end
      end

      MAP = {}
      MAP[1]  = Float
      MAP[2]  = String
      MAP[3]  = Hash
      MAP[4]  = Array
      MAP[5]  = Binary
      # MAP[6]  = undefined - deprecated
      MAP[7]  = ObjectId
      MAP[8]  = TrueClass
      MAP[9]  = Time
      MAP[10] = NilClass
      MAP[11] = Regexp
      # MAP[12] = db pointer - deprecated
      MAP[13] = Code
      MAP[14] = Symbol
      MAP[15] = CodeWithScope
      MAP[16] = Integer
      MAP[17] = Timestamp
      MAP[18] = Integer64
      MAP[255] = MinKey
      MAP[127] = MaxKey

      FLOAT = 1.chr.freeze
      STRING = 2.chr.freeze
      HASH = 3.chr.freeze
      ARRAY = 4.chr.freeze
      BINARY = 5.chr.freeze
      OBJECT_ID = 7.chr.freeze
      BOOLEAN = 8.chr.freeze
      TIME = 9.chr.freeze
      NULL = 10.chr.freeze
      REGEX = 11.chr.freeze
      CODE = 13.chr.freeze
      SYMBOL = 14.chr.freeze
      CODE_WITH_SCOPE = 15.chr.freeze
      INT32 = 16.chr.freeze
      INT64 = 18.chr.freeze
      MAX_KEY = 127.chr.freeze
      MIN_KEY = 255.chr.freeze

      TRUE = 1.chr.freeze
    end
  end
end
