module Moped
  class Session

    # @api private
    class Context

      attr_reader :session

      def initialize(session)
        @session = session
      end

      def read_preference
        session.read_preference
      end

      def write_concern
        session.write_concern
      end

      def cluster
        session.cluster
      end

      def query(database, collection, selector, options = {})
        read_preference.with_node(cluster) do |node|
          node.query(database, collection, selector, query_options(options))
        end
      end

      def command(database, command)
        read_preference.with_node(cluster) do |node|
          node.command(database, command, query_options({}))
        end
      end

      def insert(database, collection, documents, options = {})
        cluster.with_primary do |node|
          node.insert(database, collection, documents, write_concern, options)
        end
      end

      def update(database, collection, selector, change, options = {})
        cluster.with_primary do |node|
          node.update(database, collection, selector, change, write_concern, options)
        end
      end

      def remove(database, collection, selector, options = {})
        cluster.with_primary do |node|
          node.remove(database, collection, selector, write_concern, options)
        end
      end

      private

      def query_options(options)
        read_preference.query_options(options)
      end
    end
  end
end
