module Moped
  module BSON
    module Extensions

      module TrueClass

        def __bson_dump__(io, key)
          io << Types::BOOLEAN
          io << key.to_bson_cstring
          io << Types::TRUE
        end

        def __safe_options__
          { safe: true }
        end
      end
    end
  end
end
