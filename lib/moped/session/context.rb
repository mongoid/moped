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
        cluster.auth[database.to_s] = [username, password]
      end

      def logout(database)
        cluster.auth.delete database.to_s
      end

      def query(database, collection, selector, options = {})
        if consistency == :eventual
          options[:flags] ||= []
          options[:flags] |= [:slave_ok]
        end

        with_node do |node|
          node.query(database, collection, selector, options)
        end
      end

      def command(database, command)
        options = consistency == :eventual ? { :flags => [:slave_ok] } : {}
        with_node do |node|
          node.command(database, command, options)
        end
      end

      def insert(database, collection, documents, options = {})
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
      end

      def update(database, collection, selector, change, options = {})
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
      end

      def remove(database, collection, selector, options = {})
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
      end

      def get_more(*args)
        raise NotImplementedError, "#get_more cannot be called on Context; it must be called directly on a node"
      end

      def kill_cursors(*args)
        raise NotImplementedError, "#kill_cursors cannot be called on Context; it must be called directly on a node"
      end

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
