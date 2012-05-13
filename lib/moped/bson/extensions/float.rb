# encoding: utf-8

module Moped
  module BSON
    # @private
    module Extensions
      module Float

        module ClassMethods
          def __bson_load__(io)
            io.read(8).unpack(FLOAT_PACK)[0]
          end
        end

        def __bson_dump__(io, key)
          io << Types::FLOAT
          io << key
          io << NULL_BYTE
          io << [self].pack(FLOAT_PACK)
        end

      end
    end
  end
end
