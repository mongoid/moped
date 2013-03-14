module Moped
  class Session

    # @api private
    class Context

      attr_reader :session

      def initialize(session)
        @session = session
      end

      def safety
        session.safety
      end

      def safe?
        session.safe?
      end

      def consistency
        session.consistency
      end

      def cluster
        session.cluster
      end

      def login(database, username, password)
        cluster.credentials[database.to_s] = [username, password]
      end

      def logout(database)
        cluster.credentials.delete(database.to_s)
      end

      def query(database, collection, selector, options = {})
        # @todo: This goes away.
        if consistency == :eventual
          options[:flags] ||= []
          options[:flags] |= [:slave_ok]
        end
        with_node do |node|
          node.query(database, collection, selector, options)
        end
        # query = Protocol::Query.new(database, collection, selector, options)
        # Operation::Read.new(query).execute(read_preference.select(ring))
      end

      def command(database, command)
        # @todo: This goes away.
        options = consistency == :eventual ? { :flags => [:slave_ok] } : {}
        with_node do |node|
          node.command(database, command, options)
        end
        # command = Protocol::Command.new(database, cmd, options)
        # Operation::Read.new(command).execute(read_preference.select(ring))
      end

      def insert(database, collection, documents, options = {})
        # @todo: This goes away.
        with_node do |node|
          if safe?
            node.pipeline do
              node.insert(database, collection, documents, options)
              node.command(database, { getlasterror: 1 }.merge(safety))
            end
          else
            node.insert(database, collection, documents, options)
          end
        end
        # insert = Protocol::Insert.new(database.name, name, documents, options)
        # Operation::Write.new(insert, concern).execute(ring.next_primary)
      end

      def update(database, collection, selector, change, options = {})
        # @todo: This goes away.
        with_node do |node|
          if safe?
            node.pipeline do
              node.update(database, collection, selector, change, options)
              node.command(database, { getlasterror: 1 }.merge(safety))
            end
          else
            node.update(database, collection, selector, change, options)
          end
        end
        # update = Protocol::Update.new(database, collection, selector, change, options))
        # Operation::Write.new(update, concern).execute(ring.next_primary)
      end

      def remove(database, collection, selector, options = {})
        # @todo: This goes away.
        with_node do |node|
          if safe?
            node.pipeline do
              node.remove(database, collection, selector, options)
              node.command(database, { getlasterror: 1 }.merge(safety))
            end
          else
            node.remove(database, collection, selector, options)
          end
        end
        # delete = Protocol::Delete.new(database, collection, selector, options)
        # Operation::Write.new(delete, concern).execute(ring.next_primary)
      end

      # @todo: This goes away.
      def with_node
        if consistency == :eventual
          cluster.with_secondary do |node|
            yield node
          end
        else
          cluster.with_primary do |node|
            yield node
          end
        end
      end
    end
  end
end
