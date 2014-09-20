require "moped/log_format/utils/color_string"

module Moped
  module LogFormat
    # Get colorize flag
    #
    # @example Get colorize flag.
    #   DefaultFormat.colorize
    #
    # @return [ true | false ] Status of colorization.
    #
    # @since 2.0.0
    def colorize
      @@colorize
    end

    # Set colorize flag
    #
    # @example Disable colorization.
    #   DefaultFormat.colorize = false
    #
    # @param [ true | false ] flag Flag to set
    #
    # @since 2.0.0
    def colorize=(flag)
      @@colorize = !!flag
    end

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
    def log(prefix, payload, runtime = nil)
      raise NotImplemented
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
    def command(event)
      raise NotImplemented
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
    def insert(event)
      raise NotImplemented
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
    def query(event)
      raise NotImplemented
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
    def update(event)
      raise NotImplemented
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
    def delete(event)
      raise NotImplemented
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
    def get_more(event)
      raise NotImplemented
    end

    # Format the cursor.close() event
    #
    # @example Format kill_cursors.
    #   Default.kill_cursors(event)
    #
    # @param [ Moped::Protocol::KillCursors ] event KillCursors event to format
    #
    # @return [ String ] Formatted string
    #
    # @since 2.0.0
    def kill_cursors(event)
      raise NotImplemented
    end

    # Format the cursor.close() event
    #
    # @example Format kill_cursors.
    #   Default.kill_cursors(event)
    #
    # @param [ Moped::Protocol::KillCursors ] event KillCursors event to format
    #
    # @return [ ColorString ] ColorString
    #
    # @since 2.0.0
    def color(string)
      ColorString.new(string, self.colorize)
    end
  end
end