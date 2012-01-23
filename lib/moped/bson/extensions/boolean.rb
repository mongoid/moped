module Moped
  module BSON
    module Extensions
      module Boolean
        module ClassMethods
          def __bson_load__(io)
            io.getbyte == 1
          end
        end
      end
    end
  end
end
