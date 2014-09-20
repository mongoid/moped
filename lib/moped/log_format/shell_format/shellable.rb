module Moped
  module LogFormat
    class ShellFormat
      module Shellable
        module ClassMethods
          def format(event)
            new(event).to_s
          end
        end

        def self.included(receiver)
          receiver.extend ClassMethods
        end

        attr_reader :event
        def initialize(event)
          @event = event
        end

        def to_s
          commands = []

          sequence.each do |item|
            commands << comandify(item)
          end

          "#{event.database}: #{commands.compact.join(".")}"
        end

        def comandify(command)
          if respond_to? :"to_shell_#{command}"
            return nil_if_blank(send(:"to_shell_#{command}"))
          end

          if respond_to? :extact_command
            return nil_if_blank(extact_command(command))
          end

          raise ArgumentError, "can't convert '#{command}' to mongodb shell command for #{self.class}"
        end

        def to_shell_db
          :db
        end

        def to_shell_collection
          event.collection
        end

        private

        def selector
          dump_json(event.selector)
        end

        def flags
          return if event.flags.blank?
          flags = Hash[event.flags.map {|f| [f, 1]}]

          dump_json(flags)
        end

        def dump_json(object)
          object.to_json(escape: false, mongo_shell_format: true)
        end

        def shell(command, *args)
          args.compact!

          "%s(%s)" % [command, args.join(", ")]
        end

        def nil_if_blank(obj)
          obj.blank? ? nil : obj
        end
      end
    end
  end
end