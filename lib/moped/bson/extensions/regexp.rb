module Moped
  module BSON
    module Extensions

      module Regexp

        def __bson_dump__(io, key)
          io << Types::REGEX
          io << key.to_bson_cstring
          io << source.to_bson_cstring
          io << 'i'  if (options & ::Regexp::IGNORECASE) != 0
          io << 'ms' if (options & ::Regexp::MULTILINE) != 0
          io << 'x'  if (options & ::Regexp::EXTENDED) != 0
          io << NULL_BYTE
        end

        module ClassMethods

          def __bson_load__(io)
            source = io.gets(NULL_BYTE).from_utf8_binary.chop!
            options = 0
            while (option = io.readbyte) != 0
              case option
              when 105 # 'i'
                options |= ::Regexp::IGNORECASE
              when 109, 115 # 'm', 's'
                options |= ::Regexp::MULTILINE
              when 120 # 'x'
                options |= ::Regexp::EXTENDED
              end
            end
            new(source, options)
          end
        end
      end
    end
  end
end
