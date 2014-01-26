# encoding: utf-8
require "moped/address"
require "moped/authenticatable"
require "moped/connection"
require "moped/executable"
require "moped/failover"
require "moped/instrumentable"
require "moped/operation"

module Moped

  # Represents a client to a node in a server cluster.
  #
  # @since 1.0.0
  class Node
    include Executable
    include Instrumentable

    # @!attribute address
    #   @return [ Address ] The address.
    # @!attribute down_at
    #   @return [ Time ] The time the node was marked as down.
    # @!attribute latency
    #   @return [ Integer ] The latency in milliseconds.
    # @!attribute options
    #   @return [ Hash ] The node options.
    # @!attribute refreshed_at
    #   @return [ Time ] The last time the node did a refresh.
    attr_reader :address, :down_at, :latency, :options, :refreshed_at

    # @!attribute credentials
    #   @return [ Hash ] The credentials of the node.
    attr_accessor :credentials

    # Is this node equal to another?
    #
    # @example Is the node equal to another.
    #   node == other
    #
    # @param [ Node ] other The other node.
    #
    # @return [ true, false ] If the addresses are equal.
    #
    # @since 1.0.0
    def ==(other)
      return false unless other.is_a?(Node)
      address.resolved == other.address.resolved
    end
    alias :eql? :==

    # Is the node an arbiter?
    #
    # @example Is the node an arbiter?
    #   node.arbiter?
    #
    # @return [ true, false ] If the node is an arbiter.
    #
    # @since 1.0.0
    def arbiter?
      !!@arbiter
    end

    # Is the node auto-discovering new peers in the cluster?
    #
    # @example Is the node auto discovering?
    #   node.auto_discovering?
    #
    # @return [ true, false ] If the node is auto discovering.
    #
    # @since 2.0.0
    def auto_discovering?
      @auto_discovering ||= options[:auto_discover].nil? ? true : options[:auto_discover]
    end

    # Execute a command against a database.
    #
    # @example Execute a command.
    #   node.command(database, { ping: 1 })
    #
    # @param [ Database ] database The database to run the command on.
    # @param [ Hash ] cmd The command to execute.
    # @options [ Hash ] options The command options.
    #
    # @raise [ OperationFailure ] If the command failed.
    #
    # @return [ Hash ] The result of the command.
    #
    # @since 1.0.0
    def command(database, cmd, options = {})
      read(Protocol::Command.new(database, cmd, options))
    end

    # Is the node currently connected?
    #
    # @example Is the node connected?
    #   node.connected?
    #
    # @return [ true, false ] If the node is connected or not.
    #
    # @since 2.0.0
    def connected?
      connection{ |conn| conn.connected? }
    end

    # Get the underlying connection for the node.
    #
    # @example Get the node's connection.
    #   node.connection
    #
    # @return [ Connection ] The connection.
    #
    # @since 2.0.0
    def connection
      pool.with do |conn|
        yield(conn)
      end
    end

    # Is the node down?
    #
    # @example Is the node down?
    #   node.down?
    #
    # @return [ Time, nil ] The time the node went down, or nil if up.
    #
    # @since 1.0.0
    def down?
      @down_at
    end

    # Force the node to disconnect from the server.
    #
    # @example Disconnect the node.
    #   node.disconnect
    #
    # @return [ true ] If the disconnection succeeded.
    #
    # @since 1.2.0
    def disconnect
      connection{ |conn| conn.disconnect }
      true
    end

    # Mark the node as down.
    #
    # @example Mark the node as down.
    #   node.down!
    #
    # @return [ nil ] Nothing.
    #
    # @since 2.0.0
    def down!
      @down_at = Time.new
      @latency = nil
      disconnect
    end

    # Yields the block if a connection can be established, retrying when a
    # connection error is raised.
    #
    # @example Ensure we are connection.
    #   node.ensure_connected do
    #     #...
    #   end
    #
    # @raises [ ConnectionFailure ] When a connection cannot be established.
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def ensure_connected(&block)
      unless (conn = stack(:connection)).empty?
        return yield(conn.first)
      end

      begin
        connection do |conn|
          stack(:connection) << conn
          connect(conn) unless conn.connected?
          conn.apply_credentials(@credentials)
          yield(conn)
        end
      rescue Exception => e
        Failover.get(e).execute(e, self, &block)
      ensure
        end_execution(:connection)
      end

    end

    # Set a flag on the node for the duration of provided block so that an
    # exception is raised if the node is no longer the primary node.
    #
    # @example Ensure this node is primary.
    #   node.ensure_primary do
    #     node.command(ismaster: 1)
    #   end
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def ensure_primary
      execute(:ensure_primary) do
        yield(self)
      end
    end

    # Execute a get more operation on the node.
    #
    # @example Execute a get more.
    #   node.get_more(database, collection, 12345, -1)
    #
    # @param [ Database ] database The database to get more from.
    # @param [ Collection ] collection The collection to get more from.
    # @param [ Integer ] cursor_id The id of the cursor on the server.
    # @param [ Integer ] limit The number of documents to limit.
    # @raise [ CursorNotFound ] if the cursor has been killed
    #
    # @return [ Message ] The result of the operation.
    #
    # @since 1.0.0
    def get_more(database, collection, cursor_id, limit)
      read(Protocol::GetMore.new(database, collection, cursor_id, limit))
    end

    # Get the hash identifier for the node.
    #
    # @example Get the hash identifier.
    #   node.hash
    #
    # @return [ Integer ] The hash identifier.
    #
    # @since 1.0.0
    def hash
      address.resolved.hash
    end

    # Creat the new node.
    #
    # @example Create the new node.
    #   Node.new("127.0.0.1:27017")
    #
    # @param [ String ] address The location of the server node.
    # @param [ Hash ] options Additional options for the node (ssl)
    #
    # @since 1.0.0
    def initialize(address, options = {})
      @options = options
      @down_at = nil
      @refreshed_at = nil
      @latency = nil
      @primary = nil
      @secondary = nil
      @credentials = {}
      @instrumenter = options[:instrumenter] || Instrumentable::Log
      @address = Address.new(address, timeout)
      @address.resolve(self)
    end

    # Insert documents into the database.
    #
    # @example Insert documents.
    #   node.insert(database, collection, [{ name: "Tool" }])
    #
    # @param [ Database ] database The database to insert to.
    # @param [ Collection ] collection The collection to insert to.
    # @param [ Array<Hash> ] documents The documents to insert.
    #
    # @return [ Message ] The result of the operation.
    #
    # @since 1.0.0
    def insert(database, collection, documents, concern, options = {})
      write(Protocol::Insert.new(database, collection, documents, options), concern)
    end

    # Kill all provided cursors on the node.
    #
    # @example Kill all the provided cursors.
    #   node.kill_cursors([ 12345 ])
    #
    # @param [ Array<Integer> ] cursor_ids The cursor ids.
    #
    # @return [ Message ] The result of the operation.
    #
    # @since 1.0.0
    def kill_cursors(cursor_ids)
      process(Protocol::KillCursors.new(cursor_ids))
    end

    # Can we send messages to this node in normal cirucmstances? This is true
    # only if the node is a primary or secondary node - arbiters or passives
    # cannot be sent anything.
    #
    # @example Is the node messagable?
    #   node.messagable?
    #
    # @return [ true, false ] If messages can be sent to the node.
    #
    # @since 2.0.0
    def messagable?
      primary? || secondary?
    end

    # Does the node need to be refreshed?
    #
    # @example Does the node require refreshing?
    #   node.needs_refresh?(time)
    #
    # @param [ Time ] time The next referesh time.
    #
    # @return [ true, false] Whether the node needs to be refreshed.
    #
    # @since 1.0.0
    def needs_refresh?(time)
      !refreshed_at || refreshed_at < time
    end

    # Is the node passive?
    #
    # @example Is the node passive?
    #   node.passive?
    #
    # @return [ true, false ] If the node is passive.
    #
    # @since 1.0.0
    def passive?
      !!@passive
    end

    # Get all the other nodes in the replica set according to the server
    # information.
    #
    # @example Get the node's peers.
    #   node.peers
    #
    # @return [ Array<Node> ] The peers.
    #
    # @since 2.0.0
    def peers
      @peers ||= []
    end

    # Execute a pipeline of commands, for example a safe mode persist.
    #
    # @example Execute a pipeline.
    #   node.pipeline do
    #     #...
    #   end
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    # @todo: Remove with piggbacked gle.
    def pipeline
      execute(:pipeline) do
        yield(self)
      end
      flush unless executing?(:pipeline)
    end

    # Is the node the replica set primary?
    #
    # @example Is the node the primary?
    #   node.primary?
    #
    # @return [ true, false ] If the node is the primary.
    #
    # @since 1.0.0
    def primary?
      !!@primary
    end

    # Processes the provided operation on this node, and will execute the
    # callback when the operation is sent to the database.
    #
    # @example Process a read operation.
    #   node.process(query) do |reply|
    #     return reply.documents
    #   end
    #
    # @param [ Message ] operation The database operation.
    # @param [ Proc ] callback The callback to run on operation completion.
    #
    # @return [ Object ] The result of the callback.
    #
    # @since 1.0.0
    def process(operation, &callback)
      if executing?(:pipeline)
        queue.push([ operation, callback ])
      else
        flush([[ operation, callback ]])
      end
    end

    # Execute a query on the node.
    #
    # @example Execute a query.
    #   node.query(database, collection, { name: "Tool" })
    #
    # @param [ Database ] database The database to query from.
    # @param [ Collection ] collection The collection to query from.
    # @param [ Hash ] selector The query selector.
    # @param [ Hash ] options The query options.
    #
    # @raise [ QueryFailure ] If the query had an error.
    #
    # @return [ Message ] The result of the operation.
    #
    # @since 1.0.0
    def query(database, collection, selector, options = {})
      read(Protocol::Query.new(database, collection, selector, options))
    end

    # Refresh information about the node, such as it's status in the replica
    # set and it's known peers.
    #
    # @example Refresh the node.
    #   node.refresh
    #
    # @raise [ ConnectionFailure ] If the node cannot be reached.
    #
    # @raise [ ReplicaSetReconfigured ] If the node is no longer a primary node and
    #   refresh was called within an +#ensure_primary+ block.
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def refresh
      if address.resolve(self)
        begin
          @refreshed_at = Time.now
          configure(command("admin", ismaster: 1))
          if !primary? && executing?(:ensure_primary)
            raise Errors::ReplicaSetReconfigured.new("#{inspect} is no longer the primary node.", {})
          elsif !messagable?
            # not primary or secondary so mark it as down, since it's probably
            # a recovering node withing the replica set
            down!
          end
        rescue Timeout::Error
          down!
        end
      end
    end

    # Execute a remove command for the provided selector.
    #
    # @example Remove documents.
    #   node.remove(database, collection, { name: "Tool" })
    #
    # @param [ Database ] database The database to remove from.
    # @param [ Collection ] collection The collection to remove from.
    # @param [ Hash ] selector The query selector.
    # @param [ Hash ] options The remove options.
    #
    # @return [ Message ] The result of the operation.
    #
    # @since 1.0.0
    def remove(database, collection, selector, concern, options = {})
      write(Protocol::Delete.new(database, collection, selector, options), concern)
    end

    # Is the node a replica set secondary?
    #
    # @example Is the node a secondary?
    #   node.secondary?
    #
    # @return [ true, false ] If the node is a secondary.
    #
    # @since 1.0.0
    def secondary?
      @secondary
    end

    # Get the timeout, in seconds, for this node.
    #
    # @example Get the timeout in seconds.
    #   node.timeout
    #
    # @return [ Integer ] The configured timeout or the default of 5.
    #
    # @since 1.0.0
    def timeout
      @timeout ||= (options[:timeout] || 5)
    end

    # Execute an update command for the provided selector.
    #
    # @example Update documents.
    #   node.update(database, collection, { name: "Tool" }, { likes: 1000 })
    #
    # @param [ Database ] database The database to update.
    # @param [ Collection ] collection The collection to update.
    # @param [ Hash ] selector The query selector.
    # @param [ Hash ] change The updates.
    # @param [ Hash ] options The update options.
    #
    # @return [ Message ] The result of the operation.
    #
    # @since 1.0.0
    def update(database, collection, selector, change, concern, options = {})
      write(Protocol::Update.new(database, collection, selector, change, options), concern)
    end

    # Get the node as a nice formatted string.
    #
    # @example Inspect the node.
    #   node.inspect
    #
    # @return [ String ] The string inspection.
    #
    # @since 1.0.0
    def inspect
      "<#{self.class.name} resolved_address=#{address.resolved.inspect}>"
    end

    private

    # Connect the node on the underlying connection.
    #
    # @example Connect the node.
    #   node.connect
    #
    # @raise [ Errors::ConnectionFailure ] If connection failed.
    #
    # @return [ true ] If the connection suceeded.
    #
    # @since 2.0.0
    def connect(conn)
      start = Time.now
      conn.connect
      @latency = Time.now - start
      @down_at = nil
      true
    end

    # Configure the node based on the return from the ismaster command.
    #
    # @api private
    #
    # @example Configure the node.
    #   node.configure(ismaster)
    #
    # @param [ Hash ] settings The result of the ismaster command.
    #
    # @since 2.0.0
    def configure(settings)
      @arbiter = settings["arbiterOnly"]
      @passive = settings["passive"]
      @primary = settings["ismaster"]
      @secondary = settings["secondary"]
      discover(settings["hosts"]) if auto_discovering?
    end

    # Discover the additional nodes.
    #
    # @api private
    #
    # @example Discover the additional nodes.
    #   node.discover([ "127.0.0.1:27019" ])
    #
    # @param [ Array<String> ] nodes The new nodes.
    #
    # @since 2.0.0
    def discover(*nodes)
      nodes.flatten.compact.each do |peer|
        node = Node.new(peer, options)
        node.credentials.merge!(@credentials)
        peers.push(node)
      end
    end

    # Flush the node operations to the database.
    #
    # @api private
    #
    # @example Flush the operations.
    #   node.flush([ command ])
    #
    # @param [ Array<Message> ] ops The operations to flush.
    #
    # @return [ Object ] The result of the operations.
    #
    # @since 2.0.0
    def flush(ops = queue)
      operations, callbacks = ops.transpose
      logging(operations) do
        replies = nil
        ensure_connected do |conn|
          conn.write(operations)
          replies = conn.receive_replies(operations)
        end
        replies.zip(callbacks).map do |reply, callback|
          callback ? callback[reply] : reply
        end.last
      end
    ensure
      ops.clear
    end

    # Yield the block with logging.
    #
    # @api private
    #
    # @example Yield with logging.
    #   logging(operations) do
    #     node.command(ismaster: 1)
    #   end
    #
    # @param [ Array<Message> ] operations The operations.
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 2.0.0
    def logging(operations)
      instrument(TOPIC, prefix: "  MOPED: #{address.resolved}", ops: operations) do
        yield if block_given?
      end
    end

    # Get the connection pool for the node.
    #
    # @api private
    #
    # @example Get the connection pool.
    #   node.pool
    #
    # @return [ Connection::Pool ] The connection pool.
    #
    # @since 2.0.0
    def pool
      @pool ||= Connection::Manager.pool(self)
    end

    # Execute a read operation.
    #
    # @api private
    #
    # @example Execute a read operation.
    #   node.read(operation)
    #
    # @param [ Message ] operation The read operation.
    #
    # @return [ Object ] The result of the read.
    #
    # @since 2.0.0
    def read(operation)
      Operation::Read.new(operation).execute(self)
    end

    # Execute a write operation.
    #
    # @api private
    #
    # @example Execute a write operation.
    #   node.write(operation, concern)
    #
    # @param [ Message ] operation The write operation.
    # @param [ WriteConcern ] concern The write concern.
    #
    # @return [ Object ] The result of the write.
    #
    # @since 2.0.0
    def write(operation, concern)
      Operation::Write.new(operation, concern).execute(self)
    end

    # Get the queue of operations.
    #
    # @api private
    #
    # @example Get the operation queue.
    #   node.queue
    #
    # @return [ Array<Message> ] The queue of operations.
    #
    # @since 2.0.0
    def queue
      stack(:pipelined_operations)
    end
  end
end
