module Moped
  module BSON
    class MaxKey
      class << self
        def ===(other)
          other == self
        end

        def __bson_load__(io)
          self
        end

        def __bson_dump__(io, key)
          io << Types::MAX_KEY
          io << key.to_bson_cstring
        end
      end
    end
  end
end
