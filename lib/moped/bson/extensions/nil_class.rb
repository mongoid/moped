module Moped
  module BSON
    module Extensions

      module NilClass

        def __bson_dump__(io, key)
          io << Types::NULL
          io << key.to_bson_cstring
        end

        module ClassMethods

          def __bson_load__(io); nil; end
        end
      end
    end
  end
end
