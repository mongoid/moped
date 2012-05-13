# encoding: utf-8

module Moped
  module BSON
    # @private
    module Extensions
      module Hash

        module ClassMethods
          def __bson_load__(io, doc = new)
            # Swallow the first four (length) bytes
            io.read 4

            while (buf = io.readbyte) != 0
              key = io.gets(NULL_BYTE).chop!

              if native_class = Types::MAP[buf]
                doc[key] = native_class.__bson_load__(io)
              end
            end

            doc
          end
        end

        def __bson_dump__(io = "", key = nil)
          if key
            io << Types::HASH
            io << key
            io << NULL_BYTE
          end

          start = io.length

          # write dummy length
          io << START_LENGTH

          each do |k, v|
            v.__bson_dump__(io, k.to_s)
          end
          io << EOD

          stop = io.length
          io[start, 4] = [stop - start].pack INT32_PACK

          io
        end
      end
    end
  end
end
