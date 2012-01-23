module Moped
  module BSON
    module Extensions
      module Time
        module ClassMethods
          def __bson_load__(io)
            at(io.read(8).unpack(INT64_PACK)[0]/1000.0)
          end
        end

        def __bson_dump__(io, key)
          io << Types::TIME
          io << key
          io << NULL_BYTE
          io << [to_f * 1000].pack(INT64_PACK)
        end
      end
    end
  end
end
