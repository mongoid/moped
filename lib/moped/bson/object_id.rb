require "digest/md5"
require "socket"

module Moped
  module BSON
    class ObjectId

      # Formatting string for outputting an ObjectId.
      @@string_format = ("%02x" * 12).freeze

      attr_reader :data

      class << self
        def from_string(string)
          raise Errors::InvalidObjectId.new(string) unless legal?(string)
          data = []
          12.times { |i| data << string[i*2, 2].to_i(16) }
          new data
        end

        def legal?(str)
          !!str.match(/^[0-9a-f]{24}$/i)
        end
      end

      def initialize(data = nil, time = nil)
        if data
          @data = data
        elsif time
          @data = @@generator.generate(time.to_i)
        else
          @data = @@generator.next
        end
      end

      def ==(other)
        BSON::ObjectId === other && data == other.data
      end
      alias eql? ==

      def hash
        data.hash
      end

      def to_s
        @@string_format % data
      end

      # Return the UTC time at which this ObjectId was generated. This may
      # be used instread of a created_at timestamp since this information
      # is always encoded in the object id.
      def generation_time
        Time.at(@data.pack("C4").unpack("N")[0]).utc
      end

      class << self
        def __bson_load__(io)
          new io.read(12).unpack('C*')
        end

      end

      def __bson_dump__(io, key)
        io << Types::OBJECT_ID
        io << key
        io << NULL_BYTE
        io << data.pack('C12')
      end

      # @api private
      class Generator
        def initialize
          # Generate and cache 3 bytes of identifying information from the current
          # machine.
          @machine_id = Digest::MD5.digest(Socket.gethostname).unpack("C3")

          @mutex = Mutex.new
          @last_timestamp = nil
          @counter = 0
        end

        # Return object id data based on the current time, incrementing a
        # counter for object ids generated in the same second.
        def next
          now = Time.new.to_i

          counter = @mutex.synchronize do
            last_timestamp, @last_timestamp = @last_timestamp, now

            if last_timestamp == now
              @counter += 1
            else
              @counter = 0
            end
          end

          generate(now, counter)
        end

        # Generate object id data for a given time using the provided +inc+.
        def generate(time, inc = 0)
          pid = Process.pid % 0xFFFF

          [
            time >> 24 & 0xFF, # 4 bytes time (network order)
            time >> 16 & 0xFF,
            time >> 8  & 0xFF,
            time       & 0xFF,
            @machine_id[0],   # 3 bytes machine
            @machine_id[1],
            @machine_id[2],
            pid  >> 8  & 0xFF, # 2 bytes process id
            pid        & 0xFF,
            inc  >> 16 & 0xFF, # 3 bytes increment
            inc  >> 8  & 0xFF,
            inc        & 0xFF,
          ]
        end
      end

      @@generator = Generator.new
    end
  end
end
