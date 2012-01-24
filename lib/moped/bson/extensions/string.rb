module Moped
  module BSON
    # @private
    module Extensions
      module String
        module ClassMethods
          def __bson_load__(io)
            io.read(*io.read(4).unpack(INT32_PACK)).chop!
          end
        end

        def __bson_dump__(io, key)
          io << Types::STRING
          io << key
          io << NULL_BYTE
          io << [length+1].pack(INT32_PACK)
          io << self
          io << NULL_BYTE
        end
      end
    end
  end
end
