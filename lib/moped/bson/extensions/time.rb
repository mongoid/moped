module Moped
  module BSON
    module Extensions

      module Time

        def __bson_dump__(io, key)
          io << Types::TIME
          io << key.to_bson_cstring
          io << [(to_i * 1000) + (usec / 1000)].pack(INT64_PACK)
        end

        module ClassMethods

          def __bson_load__(io)
            seconds, fragment = io.read(8).unpack(INT64_PACK)[0].divmod 1000
            at(seconds, fragment * 1000).utc
          end
        end
      end
    end
  end
end
