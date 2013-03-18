# encoding: utf-8
require "moped/read_preference/selectable"
require "moped/read_preference/nearest"
require "moped/read_preference/primary"
require "moped/read_preference/primary_preferred"
require "moped/read_preference/secondary"
require "moped/read_preference/secondary_preferred"

module Moped

  # Provides behaviour around getting various read preference implementations.
  #
  # @since 2.0.0
  module ReadPreference
    extend self

    # Hash lookup for the read preference classes based off the symbols
    # provided in configuration.
    #
    # @since 2.0.0
    PREFERENCES = {
      nearest: Nearest,
      primary: Primary,
      primary_preferred: PrimaryPreferred,
      secondary: Secondary,
      secondary_preferred: SecondaryPreferred
    }.freeze

    # Get a read preference for the provided name. Valid names are:
    #   - :nearest
    #   - :primary
    #   - :primary_preferred
    #   - :secondary
    #   - :secondary_preferred
    #
    # @example Get the primary read preference.
    #   Moped::ReadPreference.get(:primary)
    #
    # @param [ Symbol ] name The name of the preference.
    # @param [ Array<Hash> ] tags The tag sets to match the node on.
    #
    # @return [ Object ] The appropriate read preference.
    #
    # @since 2.0.0
    def get(name, tags = nil)
      PREFERENCES.fetch(name.to_sym).new(tags)
    end
  end
end
