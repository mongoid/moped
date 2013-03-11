# encoding: utf-8
module Moped
  module WriteConcern

    # Unverified write concerns are fire and forget.
    #
    # @since 2.0.0
    class Unverified

      # Constant for a noop getlasterror command.
      #
      # @since 2.0.0
      NOOP = nil

      # Get the gle command associated with this write concern.
      #
      # @example Get the gle command.
      #   propagate.command(database)
      #
      # @param [ String ] database The database to execute on.
      #
      # @return [ nil ] nil, since unverified writes perform no gle.
      #
      # @since 2.0.0
      def command(database)
        NOOP
      end
    end
  end
end
