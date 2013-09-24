# encoding: utf-8
require "moped/write_concern/propagate"
require "moped/write_concern/unverified"

module Moped

  # Provides behaviour on getting the correct write concern for an option.
  #
  # @since 2.0.0
  module WriteConcern
    extend self

    # Get the corresponding write concern for the provided value. If the value
    # is unverified we get that concern, otherwise we get propagate.
    #
    # @example Get the appropriate write concern.
    #   Moped::WriteConcern.get(w: 3)
    #
    # @param [ Symbol, String, Hash ] The value to use to get the concern.
    #
    # @return [ Unverified, Propagate ] The appropriate write concern.
    #
    # @since 2.0.0
    def get(value)
      propagate = value[:w] || value["w"]
      if propagate == 0 || propagate == -1
        Unverified.new
      else
        Propagate.new(value)
      end
    end
  end
end
