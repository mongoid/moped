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
          io << key
          io << NULL_BYTE
        end
      end
    end
  end
end
