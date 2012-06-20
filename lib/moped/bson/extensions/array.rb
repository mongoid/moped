module Moped
  module BSON
    # @private
    module Extensions
      module Array

        module ClassMethods
          def __bson_load__(io, array = new)
            # Swallow the first four (length) bytes
            io.read 4

            while (buf = io.readbyte) != 0
              io.gets(NULL_BYTE)
              array << Types::MAP[buf].__bson_load__(io)
            end

            array
          end
        end

        def __bson_dump__(io, key)
          io << Types::ARRAY
          io << key.to_bson_cstring

          start = io.length

          # write dummy length
          io << START_LENGTH

          each_with_index do |value, index|
            value.__bson_dump__(io, index.to_s)
          end
          io << EOD

          stop = io.length
          io[start, 4] = [stop - start].pack(INT32_PACK)

          io
        end
      end
    end
  end
end
