module Moped
  module LogFormat
    class ShellFormat
      class Delete
        include Moped::LogFormat::ShellFormat::Shellable

        def sequence
          [
            :db, :collection, :delete
          ]
        end

        def to_shell_delete
          return shell :remove, selector, flags
        end
      end
    end
  end
end