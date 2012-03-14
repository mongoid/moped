module Moped
  module BSON
    # @private
    module Extensions
      module Symbol
        module ClassMethods
          def __bson_load__(io)
            io.read(*io.read(4).unpack(INT32_PACK)).chop!.force_encoding('utf-8').intern
          end
        end

        def __bson_dump__(io, key)
          io << Types::SYMBOL
          io << key
          io << NULL_BYTE

          str = to_s.encode('utf-8').force_encoding('binary')
          io << [str.bytesize+1].pack(INT32_PACK)
          io << str
          io << NULL_BYTE
        end
      end
    end
  end
end
