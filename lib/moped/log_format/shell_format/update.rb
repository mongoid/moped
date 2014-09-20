module Moped
  module LogFormat
    class ShellFormat
      class Update
        include Moped::LogFormat::ShellFormat::Shellable

        def sequence
          [
            :db, :collection, :update
          ]
        end

        def to_shell_update
          return shell :update, selector, update, flags
        end

        private

        def selector
          dump_json(event.selector)
        end

        def update
          dump_json(event.selector)
        end

        def flags
          return if event.flags.blank?
          dump_json(event.flags)
        end
      end
    end
  end
end