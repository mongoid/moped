module Moped
  module BSON
    module Extensions

      module Float

        def __bson_dump__(io, key)
          io << Types::FLOAT
          io << key.to_bson_cstring
          io << [self].pack(FLOAT_PACK)
        end

        module ClassMethods

          def __bson_load__(io)
            io.read(8).unpack(FLOAT_PACK)[0]
          end
        end
      end
    end
  end
end
