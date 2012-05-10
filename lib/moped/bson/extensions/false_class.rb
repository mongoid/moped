# encoding: utf-8

module Moped
  module BSON
    # @private
    module Extensions
      module FalseClass
        def __bson_dump__(io, key)
          io << Types::BOOLEAN
          io << key
          io << NULL_BYTE
          io << NULL_BYTE
        end
      end
    end
  end
end
