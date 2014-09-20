module Moped
  module LogFormat
    class ShellFormat
      class Insert
        include Moped::LogFormat::ShellFormat::Shellable

        def sequence
          [
            :db, :collection, :insert
          ]
        end

        def to_shell_insert
          return shell :insert, documents, flags
        end

        private

        def documents
          if event.documents.size == 1
            dump_json(event.documents.first)
          else
            dump_json(event.documents.first)
          end
        end

        def flags
          return if event.flags.blank?
          dump_json(event.flags)
        end
      end
    end
  end
end