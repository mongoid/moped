module Moped
  module BSON

    # A time representation in BSON.
    class Timestamp < Struct.new(:seconds, :increment)

      # Serialize the time to the stream.
      #
      # @example Serialize the time.
      #   time.__bson_dump__("", "created_at")
      #
      # @param [ String ] io The raw bytes.
      # @param [ String ] key The field name.
      #
      # @since 1.0.0
      def __bson_dump__(io, key)
        io << [17, key, increment, seconds].pack('cZ*l2')
      end

      class << self

        # Deserialize the timestamp to an object.
        #
        # @example Deserialize the time.
        #   Moped::BSON::Timestamp.__bson_load__(string)
        #
        # @param [ String ] io The raw bytes.
        #
        # @return [ Timestamp ] The time.
        #
        # @since 1.0.0
        def __bson_load__(io)
          new(*io.read(8).unpack('l2').reverse)
        end
      end
    end
  end
end
