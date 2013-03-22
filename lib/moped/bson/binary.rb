module Moped
  module BSON

    # Represents binary data in the BSON specification.
    class Binary

      SUBTYPE_MAP = {
        generic:  0.chr,
        function: 1.chr,
        old:      2.chr,
        uuid:     3.chr,
        md5:      5.chr,
        user:     128.chr
      }.freeze

      SUBTYPE_TYPES = SUBTYPE_MAP.invert.freeze

      attr_reader :data, :type

      # Dump the binary into it's raw bytes.
      #
      # @example Dump the binary to raw bytes.
      #   binary.__bson_dump__(string, "data")
      #
      # @param [ String ] io The raw bytes to write to.
      # @param [ String ] key The field name.
      #
      # @since 1.0.0
      def __bson_dump__(io, key)
        io << Types::BINARY
        io << key
        io << NULL_BYTE

        if type == :old
          io << [data.bytesize + 4].pack(INT32_PACK)
          io << SUBTYPE_MAP[type]
          io << [data.bytesize].pack(INT32_PACK)
          io << data
        else
          io << [data.bytesize].pack(INT32_PACK)
          io << SUBTYPE_MAP[type]
          io << data
        end
      end

      # Check equality on the object.
      #
      # @example Check equality.
      #   object == other
      #
      # @param [ Object ] other The object to check against.
      #
      # @return [ true, false ] If the objects are equal.
      #
      # @since 1.0.0
      def ==(other)
        BSON::Binary === other && data == other.data && type == other.type
      end
      alias :eql? :==

      # Gets the hash code for the object.
      #
      # @example Get the hash code.
      #   object.hash
      #
      # @return [ Fixnum ] The hash code.
      #
      # @since 1.0.0
      def hash
        [data, type].hash
      end

      # Create the new binary type.
      #
      # @example Create the new binary.
      #   Moped::BSON::Binary.new(:md5, data)
      #
      # @param [ Symbol ] type The type of data. Should be one of :generic,
      #   :function, :old, :uuid, :md5, :user
      # @param [ Object ] data The binary data.
      #
      # @since 1.0.0
      def initialize(type, data)
        @type = type
        @data = data
      end

      # Gets the string inspection for the object.
      #
      # @example Get the string inspection.
      #   object.inspect
      #
      # @return [ String ] The inspection.
      #
      # @since 1.0.0
      def inspect
        "#<#{self.class.name} type=#{type.inspect} length=#{data.bytesize}>"
      end

      # Get the string representation of the object.
      #
      # @example Get the string representation.
      #   object.to_s
      #
      # @return [ String ] The string representation.
      #
      # @since 1.0.0
      def to_s
        data.to_s
      end

      class << self

        # Load the BSON from the raw data to a binary.
        #
        # @example Load the raw data.
        #   Moped::BSON::Binary.__bson_load__(data)
        #
        # @param [ String ] io The raw bytes of data.
        #
        # @return [ Binary ] The binary object.
        #
        # @since 1.0.0
        def __bson_load__(io)
          length, = io.read(4).unpack(INT32_PACK)
          type = SUBTYPE_TYPES[io.read(1)]
          if type == :old
            length -= 4
            io.read(4)
          end
          data = io.read(length)
          new(type, data)
        end
      end
    end
  end
end
