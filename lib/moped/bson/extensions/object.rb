module Moped
  module BSON
    # @private
    module Extensions
      module Object

        def __safe_options__
          self
        end
      end
    end
  end
end
