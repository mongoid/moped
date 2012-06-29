module Moped
  module BSON
    # @private
    module Extensions
      module Object

        def __safe_options__
          self
        end

        def one_nine_two?
          RUBY_VERSION.match(/1\.9\.2/)
        end
      end
    end
  end
end
