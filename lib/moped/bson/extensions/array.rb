module Moped
  module BSON
    module Extensions

      module Array

        def __bson_dump__(io, key)
          io << Types::ARRAY
          io << key.to_bson_cstring
          start = io.bytesize
          io << START_LENGTH # write dummy length
          index, length = 0, self.length
          while index < length
            slice(index).__bson_dump__(io, index.to_s)
            index += 1
          end
          io << EOD
          stop = io.bytesize
          io[start, 4] = [stop - start].pack(INT32_PACK)
          io
        end

        module ClassMethods

          def __bson_load__(io, array = new)
            io.read(4) # Swallow the first four (length) bytes
            while (buf = io.readbyte) != 0
              io.gets(NULL_BYTE)
              array << Types::MAP[buf].__bson_load__(io)
            end
            array
          end
        end
      end
    end
  end
end
