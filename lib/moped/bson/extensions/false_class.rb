module Moped
  module BSON
    module Extensions

      module FalseClass

        def __bson_dump__(io, key)
          io << Types::BOOLEAN
          io << key.to_bson_cstring
          io << NULL_BYTE
        end

        def __safe_options__
          false
        end
      end
    end
  end
end
