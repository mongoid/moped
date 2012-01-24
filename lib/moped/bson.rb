require "moped/bson/extensions"

require "moped/bson/code"
require "moped/bson/object_id"
require "moped/bson/max_key"
require "moped/bson/min_key"
require "moped/bson/timestamp"

require "moped/bson/document"
require "moped/bson/types"

module Moped
  module BSON
    EOD = NULL_BYTE = "\u0000".freeze

    INT32_PACK = 'l'.freeze
    INT64_PACK = 'q'.freeze
    FLOAT_PACK = 'E'.freeze

    START_LENGTH = [0].pack(INT32_PACK).freeze
  end
end
