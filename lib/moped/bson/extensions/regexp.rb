module Moped
  module BSON
    # @private
    module Extensions
      module Regexp
        module ClassMethods
          def __bson_load__(io)
            source = io.gets(NULL_BYTE).chop!.force_encoding('utf-8')
            options = 0
            while (option = io.getbyte) != 0
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

        def __bson_dump__(io, key)
          io << Types::REGEX
          io << key.to_bson_cstring

          io << source.to_bson_cstring

          io << 'i'  if (options & ::Regexp::IGNORECASE) != 0
          io << 'ms' if (options & ::Regexp::MULTILINE) != 0
          io << 'x'  if (options & ::Regexp::EXTENDED) != 0
          io << NULL_BYTE
        end
      end
    end
  end
end
