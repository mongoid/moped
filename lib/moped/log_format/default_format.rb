require "moped/log_format"

module Moped
  module LogFormat
    class DefaultFormat
      extend LogFormat

      self.colorize = true

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
        [
          color(prefix).magenta.bold,
          payload,
          color("runtime: #{runtime}").blue
        ].join(' ')
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
        type = color("COMMAND").bold
        "%-12s database=%s command=%s" % [type, event.database, event.selector.inspect]
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
        type = color("INSERT").bold

        "%-12s database=%s collection=%s documents=%s flags=%s" % [type, event.database,
                                                                   event.collection, event.documents.inspect,
                                                                   event.flags.inspect]
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
        type = color("QUERY").bold
        fields = []
        fields << ["%-12s", type]
        fields << ["database=%s", event.database]
        fields << ["collection=%s", event.collection]
        fields << ["selector=%s", event.selector.inspect]
        fields << ["flags=%s", event.flags.inspect]
        fields << ["limit=%s", event.limit.inspect]
        fields << ["skip=%s", event.skip.inspect]
        fields << ["batch_size=%s", event.batch_size.inspect]
        fields << ["fields=%s", event.fields.inspect]
        f, v = fields.transpose
        f.join(" ") % v
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
        type = color("UPDATE").bold

        "%-12s database=%s collection=%s selector=%s update=%s flags=%s" % [type, event.database,
                                                                            event.collection,
                                                                            event.selector.inspect,
                                                                            event.update.inspect,
                                                                            event.flags.inspect]
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
        type = color("DELETE").bold

        "%-12s database=%s collection=%s selector=%s flags=%s" % [type, event.database, event.collection,
                                                                  event.selector.inspect, event.flags.inspect]
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
        type = color("GET_MORE").bold
        "%-12s database=%s collection=%s limit=%s cursor_id=%s" % [type, event.database,
                                                                   event.collection, event.limit,
                                                                   event.cursor_id]
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
      def self.kill_cursors(event)
        type = color("KILL_CURSORS").bold
        "%-12s cursor_ids=%s" % [type, event.cursor_ids.inspect]
      end
    end
  end
end