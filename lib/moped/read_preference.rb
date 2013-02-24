require "moped/read_preference/nearest"
require "moped/read_preference/primary"
require "moped/read_preference/primary_preferred"
require "moped/read_preference/secondary"
require "moped/read_preference/secondary_preferred"

module Moped
  module ReadPreference
    extend self

    PREFERENCES = {
      nearest: Nearest,
      primary: Primary,
      primary_preferred: PrimaryPreferred,
      secondary: Secondary
    }

    def get(name)
      PREFERENCES.fetch(name)
    end
  end
end
