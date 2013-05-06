module Moped
  module Protocol

    # The base class for building all messages needed to implement the Mongo
    # Wire Protocol. It provides a minimal DSL for defining typed fields for
    # serialization and deserialization over the wire.
    #
    # @example
    #
    #   class KillCursors < Moped::Protocol::Message
    #     # header fields
    #     int32 :length
    #     int32 :request_id
    #     int32 :response_to
    #     int32 :op_code
    #
    #     # message fields
    #     int32 :reserved
    #     int32 :number_of_cursors
    #     int64 :cursor_ids, type: :array
    #
    #     # Customize field reader
    #     def number_of_cursors
    #       cursor_ids.length
    #     end
    #   end
    #
    # Note that all messages *must* implement the header fields required by the
    # Mongo Wire Protocol, namely:
    #
    #   int32 :length
    #   int32 :request_id
    #   int32 :response_to
    #   int32 :op_code
    #
    module Message

      # Default implementation for a message is to do nothing when receiving
      # replies.
      #
      # @example Receive replies.
      #   message.receive_replies(connection)
      #
      # @param [ Connection ] connection The connection.
      #
      # @return [ nil ] nil.
      #
      # @since 1.0.0
      def receive_replies(connection); end

      # Serializes the message and all of its fields to a new buffer or to the
      # provided buffer.
      #
      # @example Serliaze the message.
      #   message.serialize
      #
      # @param [ String ] buffer A buffer to serialize to.
      #
      # @return [ String ] The result of serliazing this message
      #
      # @since 1.0.0
      def serialize(buffer = "")
        raise NotImplementedError, "This method is generated after calling #finalize on a message class"
      end
      alias :to_s :serialize

      # @return [String] the nicely formatted version of the message
      def inspect
        fields = self.class.fields.map do |field|
          "@#{field}=" + __send__(field).inspect
        end
        "#<#{self.class.name}\n" <<
        "  #{fields * "\n  "}>"
      end
      class << self

        # Extends the including class with +ClassMethods+.
        #
        # @param [Class] subclass the inheriting class
        def included(base)
          super
          base.extend(ClassMethods)
        end
        private :included
      end

      # Provides a DSL for defining struct-like fields for building messages
      # for the Mongo Wire.
      #
      # @example
      #   class Command
      #     extend Message::ClassMethods
      #
      #     int32 :length
      #   end
      #
      #   Command.fields # => [:length]
      #   command = Command.new
      #   command.length = 12
      #   command.serialize_length("") # => "\f\x00\x00\x00"
      module ClassMethods

        # @return [Array] the fields defined for this message
        def fields
          @fields ||= []
        end

        # Declare a null terminated string field.
        #
        # @example
        #   class Query < Message
        #     cstring :collection
        #   end
        #
        # @param [String] name the name of this field
        def cstring(name)
          attr_accessor name

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def serialize_#{name}(buffer)
              buffer << #{name}
              buffer << 0
            end
          RUBY

          fields << name
        end

        # Declare a BSON Document field.
        #
        # @example
        #   class Update < Message
        #     document :selector
        #   end
        #
        # @example optional document field
        #   class Query < Message
        #     document :selector
        #     document :fields, optional: true
        #   end
        #
        # @example array of documents
        #   class Reply < Message
        #     document :documents, type: :array
        #   end
        #
        # @param [String] name the name of this field
        # @param [Hash] options the options for this field
        # @option options [:array] :type specify an array of documents
        # @option options [Boolean] :optional specify this field as optional
        def document(name, options = {})
          attr_accessor name

          if options[:optional]
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def serialize_#{name}(buffer)
                buffer << #{name}.to_bson if #{name}
              end
            RUBY
          elsif options[:type] == :array
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def serialize_#{name}(buffer)
                #{name}.each do |document|
                  buffer << document.to_bson
                end
              end
            RUBY
          else
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def serialize_#{name}(buffer)
                buffer << #{name}.to_bson
              end
            RUBY
          end

          fields << name
        end

        # Declare a flag field (32 bit signed integer)
        #
        # @example
        #   class Update < Message
        #     flags :flags, upsert: 2 ** 0,
        #                   multi:  2 ** 1
        #   end
        #
        # @param [String] name the name of this field
        # @param [Hash{Symbol => Number}] flags the flags for this flag field
        def flags(name, flag_map = {})
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              @#{name} ||= []
            end

            def #{name}=(flags)
              if flags.is_a? Numeric
                @#{name} = #{name}_from_int(flags)
              else
                @#{name} = flags
              end
            end

            def #{name}_as_int
              bits = 0
              flags = self.#{name}
              #{flag_map.map { |flag, value| "bits |= #{value} if flags.include? #{flag.inspect}" }.join "\n"}
              bits
            end

            def #{name}_from_int(bits)
              flags = []
              #{flag_map.map { |flag, value| "flags << #{flag.inspect} if #{value} & bits == #{value}" }.join "\n"}
              flags
            end

            def serialize_#{name}(buffer)
              buffer << [#{name}_as_int].pack('l<')
            end

            def deserialize_#{name}(buffer)
              bits, = buffer.read(4).unpack('l<')

              self.#{name} = bits
            end
          RUBY

          fields << name
        end

        # Declare a 32 bit signed integer field.
        #
        # @example
        #   class Query < Message
        #     int32 :length
        #   end
        #
        # @param [String] name the name of this field
        def int32(name)
          attr_writer name

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              @#{name} ||= 0
            end

            def serialize_#{name}(buffer)
              buffer << [#{name}].pack('l<')
            end

            def deserialize_#{name}(buffer)
              self.#{name}, = buffer.read(4).unpack('l<')
            end
          RUBY

          fields << name
        end

        # Declare a 64 bit signed integer field.
        #
        # @example
        #   class Query < Message
        #     int64 :cursor_id
        #   end
        #
        # @example with array type
        #   class KillCursors < Message
        #     int64 :cursor_ids, type: :array
        #   end
        #
        # @param [String] name the name of this field
        # @param [Hash] options the options for this field
        # @option options [:array] :type specify an array of 64 bit ints
        def int64(name, options = {})
          attr_writer name

          if options[:type] == :array
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{name}
                @#{name} ||= []
              end

              def serialize_#{name}(buffer)
                buffer << #{name}.pack('q<*')
              end

              def deserialize_#{name}(buffer)
                raise NotImplementedError
              end
            RUBY
          else
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{name}
                @#{name} ||= 0
              end

              def serialize_#{name}(buffer)
                buffer << [#{name}].pack('q<')
              end

              def deserialize_#{name}(buffer)
                self.#{name}, = buffer.read(8).unpack('q<')
              end
            RUBY
          end

          fields << name
        end

        # Declares the message class as complete, and defines its serialization
        # method from the declared fields.
        def finalize
          class_eval <<-EOS, __FILE__, __LINE__ + 1
            def serialize(buffer = "")
              start = buffer.bytesize
              #{fields.map { |f| "serialize_#{f}(buffer)" }.join("\n")}
              self.length = buffer.bytesize - start
              buffer[start, 4] = serialize_length("")
              buffer
            end
            alias :to_s :serialize
          EOS
        end

        private

        # This ensures that subclasses of the primary wire message classes have
        # identical fields.
        def inherited(subclass)
          super
          subclass.fields.replace(fields)
        end
      end
    end
  end
end
