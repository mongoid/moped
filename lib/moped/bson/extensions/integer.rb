# encoding: utf-8

module Moped
  module BSON
    # @private
    module Extensions
      module Integer
        INT32_MIN = (-(1 << 31)+1)
        INT32_MAX = ((1<<31)-1)

        INT64_MIN = (-2**64 / 2)
        INT64_MAX = (2**64 / 2 - 1)

        module ClassMethods
          def __bson_load__(io, bignum=false)
            io.read(4).unpack(INT32_PACK)[0]
          end
        end

        def __bson_dump__(io, key)
          if self >= INT32_MIN && self <= INT32_MAX
            io << Types::INT32
            io << key
            io << NULL_BYTE
            io << [self].pack(INT32_PACK)
          elsif self >= INT64_MIN && self <= INT64_MAX
            io << Types::INT64
            io << key
            io << NULL_BYTE
            io << [self].pack(INT64_PACK)
          else
            raise RangeError.new("MongoDB can only handle 8-byte ints")
          end
        end

      end
    end
  end
end
