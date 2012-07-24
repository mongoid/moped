module Moped
  module BSON
    class Timestamp < Struct.new(:seconds, :increment)
      class << self
        def __bson_load__(io)
          new(*io.read(8).unpack('l2').reverse)
        end
      end

      def __bson_dump__(io, key)
        io << [17, key, increment, seconds].pack('cZ*l2')
      end
    end
  end
end
