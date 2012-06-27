module Moped
  module BSON
    class Binary

      SUBTYPE_MAP = {
        generic:  "\x00",
        function: "\x01",
        old:      "\x02",
        uuid:     "\x03",
        md5:      "\x05",
        user:     "\x80"
      }

      attr_reader :data, :type

      def initialize(type, data)
        @type = type
        @data = data
      end

      class << self
        def __bson_load__(io)
          length, = io.read(4).unpack(INT32_PACK)
          type = SUBTYPE_MAP.invert[io.read(1)]

          if type == :old
            length -= 4
            io.read(4)
          end

          data = io.read length
          new(type, data)
        end
      end

      def ==(other)
        BSON::Binary === other && data == other.data && type == other.type
      end
      alias eql? ==

      def hash
        [data, type].hash
      end

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

      def inspect
        "#<#{self.class.name} type=#{type.inspect} length=#{data.bytesize}>"
      end

      def to_s
        data.to_s
      end
    end
  end
end
