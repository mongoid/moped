module Moped
  module BSON
    module Extensions

      module String

        def __bson_dump__(io, key)
          io << Types::STRING
          io << key.to_bson_cstring
          data = to_utf8_binary
          io << [ data.bytesize + 1 ].pack(INT32_PACK)
          io << data
          io << NULL_BYTE
        end

        def to_bson_cstring
          if include? NULL_BYTE
            raise EncodingError, "#{inspect} cannot be converted to a BSON " \
              "cstring because it contains a null byte"
          end
          to_utf8_binary << NULL_BYTE
        end

        def to_utf8_binary
          encode(Moped::BSON::UTF8_ENCODING).force_encoding(Moped::BSON::BINARY_ENCODING)
        rescue EncodingError
          data = dup.force_encoding(Moped::BSON::UTF8_ENCODING)
          raise unless data.valid_encoding?
          data.force_encoding(Moped::BSON::BINARY_ENCODING)
        end

        def from_utf8_binary
          force_encoding(Moped::BSON::UTF8_ENCODING).encode!
        end

        module ClassMethods

          def __bson_load__(io)
            io.read(*io.read(4).unpack(INT32_PACK)).from_utf8_binary.chop!
          end
        end
      end
    end
  end
end
