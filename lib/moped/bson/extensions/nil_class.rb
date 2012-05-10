# encoding: utf-8

module Moped
  module BSON
    # @private
    module Extensions
      module NilClass
        module ClassMethods
          def __bson_load__(io)
            nil
          end
        end

        def __bson_dump__(io, key)
          io << Types::NULL
          io << key
          io << NULL_BYTE
        end
      end
    end
  end
end
