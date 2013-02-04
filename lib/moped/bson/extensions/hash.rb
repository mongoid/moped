module Moped
  module BSON
    module Extensions

      module Hash

        def __bson_dump__(io = "", key = nil)
          if key
            io << Types::HASH
            io << key.to_bson_cstring
          end
          start = io.bytesize
          io << START_LENGTH # write dummy length
          each do |k, v|
            v.__bson_dump__(io, k.to_s)
          end
          io << EOD
          stop = io.bytesize
          io[start, 4] = [stop - start].pack INT32_PACK
          io
        end

        module ClassMethods

          def __bson_load__(io, doc = new)
            io.read(4) # Swallow the first four (length) bytes
            while (buf = io.readbyte) != 0
              key = io.gets(NULL_BYTE).from_utf8_binary.chop!
              if native_class = Types::MAP[buf]
                doc[key] = native_class.__bson_load__(io)
              end
            end
            doc
          end
        end
      end
    end
  end
end
