# encoding: utf-8
require "forwardable"
require "moped/failover"
require "moped/instrumentable"
require "moped/operation"

module Moped

  # Represents a client to a node in a server cluster.
  #
  # @api private
  class Node
    extend Forwardable
    include Instrumentable

    # @attribute [r] address The address of the node.
    # @attribute [r] down_at The time the server node went down.
    # @attribute [r] ip_address The node's ip.
    # @attribute [r] port The connection port.
    # @attribute [r] resolved_address The host/port pair.
    # @attribute [r] timeout The connection timeout.
    # @attribute [r] options Additional options for the node (ssl).
    attr_reader :address, :down_at, :ip_address, :port, :resolved_address, :timeout, :options

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
      resolved_address == other.resolved_address
    end
    alias :eql? :==

    # Apply the authentication details to this node.
    #
    # @example Apply authentication.
    #   node.apply_auth([ :db, "user", "pass" ])
    #
    # @param [ Array<String> ] credentials The db, username, and password.
    #
    # @return [ Node ] The authenticated node.
    #
    # @since 1.0.0
    def apply_auth(credentials)
      unless auth == credentials
        logouts = auth.keys - credentials.keys
        logouts.each { |database| logout(database) }
        credentials.each do |database, (username, password)|
          login(database, username, password) unless auth[database] == [username, password]
        end
      end
      self
    end

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

    # Get the authentication details for this node.
    #
    # @example Get the authentication details.
    #   node.auth
    #
    # @return [ Hash ] Get the authentication details.
    #
    # @since 1.0.0
    def auth
      @auth ||= {}
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
      operation = Protocol::Command.new(database, cmd, options)
      Operation::Read.new(operation).execute(self)
    end

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
    def connect
      connection.connect
      @down_at = nil
      true
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
      connection.connected?
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
      @connection ||= Connection.new(ip_address, port, timeout, options)
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
      auth.clear
      connection.disconnect
      true
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
      return yield if Threaded.executing?(:connection)
      Threaded.begin_execution(:connection)
      begin
        connect unless connected?
        yield
      rescue Exception => e
        Failover.get(e).execute(e, self, &block)
      end
    ensure
      Threaded.end_execution(:connection)
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
      Threaded.begin_execution(:ensure_primary)
      yield
    ensure
      Threaded.end_execution(:ensure_primary)
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
      operation = Protocol::GetMore.new(database, collection, cursor_id, limit)
      Operation::Read.new(operation).execute(self)
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
      resolved_address.hash
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
      @address = address
      @options = options
      @timeout = options[:timeout] || 5
      @down_at = nil
      @refreshed_at = nil
      @primary = nil
      @secondary = nil
      @instrumenter = options[:instrumenter] || Instrumentable::Log
      resolve_address
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
    def insert(database, collection, documents, options = {})
      process(Protocol::Insert.new(database, collection, documents, options))
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
      !@refreshed_at || @refreshed_at < time
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
    def pipeline
      Threaded.begin_execution(:pipeline)
      begin
        yield
      ensure
        Threaded.end_execution(:pipeline)
      end
      flush unless Threaded.executing?(:pipeline)
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
      if Threaded.executing?(:pipeline)
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
      operation = Protocol::Query.new(database, collection, selector, options)
      Operation::Read.new(operation).execute(self)
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
      if resolve_address
        begin
          info = command("admin", ismaster: 1)
          @refreshed_at = Time.now
          configure(info)
          if !primary? && Threaded.executing?(:ensure_primary)
            raise Errors::ReplicaSetReconfigured.new("#{inspect} is no longer the primary node.", {})
          elsif !primary? && !secondary?
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
    def remove(database, collection, selector, options = {})
      process(Protocol::Delete.new(database, collection, selector, options))
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
    def update(database, collection, selector, change, options = {})
      process(Protocol::Update.new(database, collection, selector, change, options))
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
      "<#{self.class.name} resolved_address=#{@resolved_address.inspect}>"
    end

    def login(database, username, password)
      getnonce = Protocol::Command.new(database, getnonce: 1)
      connection.write [getnonce]
      result = connection.read.documents.first
      raise Errors::OperationFailure.new(getnonce, result) unless result["ok"] == 1
      authenticate = Protocol::Commands::Authenticate.new(database, username, password, result["nonce"])
      connection.write [authenticate]
      result = connection.read.documents.first
      raise Errors::AuthenticationFailure.new(authenticate, result) unless result["ok"] == 1
      auth[database] = [username, password]
    end

    def logout(database)
      command = Protocol::Command.new(database, logout: 1)
      connection.write [command]
      result = connection.read.documents.first
      raise Errors::OperationFailure.new(command, result) unless result["ok"] == 1
      auth.delete(database)
    end

    private

    def flush(ops = queue)
      operations, callbacks = ops.transpose
      logging(operations) do
        ensure_connected do
          connection.write(operations)
          replies = connection.receive_replies(operations)
          replies.zip(callbacks).map do |reply, callback|
            callback ? callback[reply] : reply
          end.last
        end
      end
    ensure
      ops.clear
    end

    # @todo Move into refresh operation.
    def configure(settings)
      @arbiter = settings["arbiterOnly"]
      @passive = settings["passive"]
      @primary = settings["ismaster"]
      @secondary = settings["secondary"]
      configure_peers(settings)
    end

    # @todo Move into refresh operation.
    def configure_peers(info)
      discover(info["primary"])
      discover(info["hosts"])
      discover(info["passives"])
      discover(info["arbiters"])
    end

    def discover(*nodes)
      nodes.flatten.compact.each do |peer|
        node = Node.new(peer, options)
        if self != node && !peers.include?(node)
          node.auth.merge!(auth)
          peers.push(node)
        end
      end
    end

    def initialize_copy(_)
      @connection = nil
    end

    def logging(operations)
      instrument(TOPIC, prefix: "  MOPED: #{resolved_address}", ops: operations) do
        yield if block_given?
      end
    end

    def queue
      Threaded.stack(:pipelined_operations)
    end

    # @todo: Move address parsing out of node.
    def parse_address
      host, port = address.split(":")
      @port = (port || 27017).to_i
      @ip_address = ::Socket.getaddrinfo(host, nil, ::Socket::AF_INET, ::Socket::SOCK_STREAM).first[3]
      @resolved_address = "#{@ip_address}:#{@port}"
    end

    # @todo: Move address parsing out of node.
    def resolve_address
      unless ip_address
        begin
          parse_address and true
        rescue SocketError
          instrument(WARN, prefix: "  MOPED:", message: "Could not resolve IP address for #{address}")
          @down_at = Time.new
          false
        end
      else
        true
      end
    end
  end
end
