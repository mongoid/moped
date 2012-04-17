require "digest/md5"
require "socket"

module Moped
  module BSON
    class ObjectId

      # Formatting string for outputting an ObjectId.
      @@string_format = ("%02x" * 12).freeze

      class << self
        def from_string(string)
          raise Errors::InvalidObjectId.new(string) unless legal?(string)
          data = ""
          12.times { |i| data << string[i*2, 2].to_i(16) }
          from_data data
        end

        def from_time(time)
          from_data @@generator.generate(time.to_i)
        end

        def legal?(str)
          !!str.match(/\A\h{24}\Z/i)
        end

        def from_data(data)
          id = allocate
          id.instance_variable_set :@data, data
          id
        end
      end

      def data
        @data ||= @@generator.next
      end

      def ==(other)
        BSON::ObjectId === other && data == other.data
      end
      alias eql? ==

      def hash
        data.hash
      end

      def to_s
        @@string_format % data.unpack("C12")
      end

      # Return the UTC time at which this ObjectId was generated. This may
      # be used instread of a created_at timestamp since this information
      # is always encoded in the object id.
      def generation_time
        Time.at(data.unpack("N")[0]).utc
      end

      class << self
        def __bson_load__(io)
          from_data(io.read(12))
        end
      end

      def __bson_dump__(io, key)
        io << Types::OBJECT_ID
        io << key
        io << NULL_BYTE
        io << data
      end

      # @api private
      class Generator
        def initialize
          # Generate and cache 3 bytes of identifying information from the current
          # machine.
          @machine_id = Digest::MD5.digest(Socket.gethostname).unpack("N")[0]

          @mutex = Mutex.new
          @counter = 0
        end

        # Return object id data based on the current time, incrementing the
        # object id counter.
        def next
          @mutex.lock
          begin
            counter = @counter = (@counter + 1) % 0xFFFFFF
          ensure
            @mutex.unlock rescue nil
          end

          generate(Time.new.to_i, counter)
        end

        # Generate object id data for a given time using the provided +counter+.
        def generate(time, counter = 0)
          [time, @machine_id, Process.pid, counter << 8].pack("N NX lXX NX")
        end
      end

      @@generator = Generator.new
    end
  end
end
