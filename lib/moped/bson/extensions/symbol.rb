module Moped
  module BSON
    module Extensions

      module Symbol

        def __bson_dump__(io, key)
          io << Types::SYMBOL
          io << key.to_bson_cstring
          data = to_utf8_binary
          io << [ data.bytesize + 1 ].pack(INT32_PACK)
          io << data
          io << NULL_BYTE
        end

        def to_bson_cstring
          to_s.to_bson_cstring
        end

        def to_utf8_binary
          to_s.to_utf8_binary
        end

        module ClassMethods

          def __bson_load__(io)
            io.read(*io.read(4).unpack(INT32_PACK)).from_utf8_binary.chop!.intern
          end
        end
      end
    end
  end
end
