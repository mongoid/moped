# encoding: utf-8
require "moped/bson/extensions"
require "moped/bson/binary"
require "moped/bson/code"
require "moped/bson/object_id"
require "moped/bson/max_key"
require "moped/bson/min_key"
require "moped/bson/timestamp"
require "moped/bson/document"
require "moped/bson/types"

module Moped

  # The module for Moped's BSON implementation.
  module BSON

    EOD = NULL_BYTE = "\u0000".freeze

    INT32_PACK = 'l'.freeze
    INT64_PACK = 'q'.freeze
    FLOAT_PACK = 'E'.freeze

    START_LENGTH = [0].pack(INT32_PACK).freeze

    BINARY_ENCODING = Encoding.find("binary")
    UTF8_ENCODING   = Encoding.find("utf-8")

    class << self

      # Create a new object id from the provided string.
      #
      # @example Create a new object id.
      #   Moped::BSON::ObjectId("4faf83c7dbf89b7b29000001")
      #
      # @param [ String ] string The string to use.
      #
      # @return [ ObjectId ] The object id.
      #
      # @since 1.0.0
      def ObjectId(string)
        ObjectId.from_string(string)
      end
    end
  end
end
