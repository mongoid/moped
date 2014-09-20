require "moped/log_format/shell_format/core_ext/unsafe_json_string"
require "moped/log_format/shell_format/core_ext/active_support/json/encoding"
require "moped/log_format/shell_format/core_ext/bson/object_id"
require "moped/log_format/shell_format/core_ext/regexp"
require "moped/log_format/shell_format/core_ext/time"

require "moped/log_format/shell_format/command"
require "moped/log_format/shell_format/query"
require "moped/log_format/shell_format/insert"
require "moped/log_format/shell_format/update"
require "moped/log_format/shell_format/delete"

module Moped
  module LogFormat
    class ShellFormat
      extend LogFormat

      # Format the provided operations log entry.
      #
      # @example Log the operations.
      #   Default.log("MOPED", {}, 30)
      #
      # @param [ String ] prefix The prefix for all operations in the log.
      # @param [ Array ] ops The operations.
      # @param [ String ] runtime The runtime in formatted ms.
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.log(prefix, payload, runtime = nil)
        line = []

        line << color(prefix).magenta.bold
        line << payload
        line << color("runtime: #{runtime}").blue if runtime

        line.join(' ')
      end

      # Format the command event
      #
      # @example Format command.
      #   Default.command(event)
      #
      # @param [ Moped::Protocol::Command ] event Command event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.command(event)
        ShellFormat::Command.format event
      end

      # Format the insert event
      #
      # @example Format insert.
      #   Default.insert(event)
      #
      # @param [ Moped::Protocol::Insert ] event Insert event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.insert(event)
        ShellFormat::Insert.format event
      end

      # Format the query event
      #
      # @example Format query.
      #   Default.query(event)
      #
      # @param [ Moped::Protocol::Query ] event Query event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.query(event)
        ShellFormat::Query.format event
      end

      # Format the query event
      #
      # @example Format query.
      #   Default.query(event)
      #
      # @param [ Moped::Protocol::Query ] event Query event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.update(event)
        ShellFormat::Update.format event
      end

      # Format the delete event
      #
      # @example Format delete.
      #   Default.delete(event)
      #
      # @param [ Moped::Protocol::Delete ] event Delete event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.delete(event)
        ShellFormat::Delete.format event
      end

      # Format the cursor.next() event
      #
      # @example Format get_more.
      #   Default.get_more(event)
      #
      # @param [ Moped::Protocol::GetMore ] event GetMore event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.get_more(event)
        "#{event.database}: cursor.next() cursor_id: #{event.cursor_id}"
      end

      # Format the db.killOp(opid) event
      #
      # @example Format kill_cursors.
      #   Default.kill_cursors(event)
      #
      # @param [ Moped::Protocol::KillCursors ] event KillCursors event to format
      #
      # @return [ String ] Formatted string
      #
      # @since 2.0.0
      def self.kill_cursors(event)
        "#{event.database}: db.killOp(#{event.cursor_id})"
      end
    end
  end
end