module Moped
  module BSON
    module Extensions

      module Object

        def __safe_options__; self; end
      end
    end
  end
end
