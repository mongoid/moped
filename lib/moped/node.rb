module Moped

  # Represents a client to a node in a server cluster.
  #
  # @api private
  class Node

    # @attribute [r] address The address of the node.
    # @attribute [r] down_at The time the server node went down.
    # @attribute [r] ip_address The node's ip.
    # @attribute [r] peers Other peers in the replica set.
    # @attribute [r] port The connection port.
    # @attribute [r] resolved_address The host/port pair.
    # @attribute [r] timeout The connection timeout.
    # @attribute [r] options Additional options for the node (ssl).
    attr_reader \
      :address,
      :down_at,
      :ip_address,
      :peers,
      :port,
      :resolved_address,
      :timeout,
      :options,
      :refreshed_at

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

      process(operation) do |reply|
        result = reply.documents.first
        if reply.command_failure?
          if reply.unauthorized? && auth.has_key?(database)
            login(database, *auth[database])
            command(database, cmd, options)
          else
            raise Errors::OperationFailure.new(operation, result)
          end
        end
        result
      end
    end

    # Force the node to disconnect from the server.
    #
    # @return [ nil ] nil.
    #
    # @since 1.2.0
    def disconnect
      auth.clear
      connection.disconnect
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
    def ensure_connected
      # Don't run the reconnection login if we're already inside an
      # +ensure_connected+ block.
      return yield if Threaded.executing?(:connection)
      Threaded.begin(:connection)
      retry_on_failure = true

      begin
        connect unless connected?
        yield
      rescue Errors::PotentialReconfiguration => e
        if e.reconfiguring_replica_set?
          raise Errors::ReplicaSetReconfigured.new(e.command, e.details)
        end
        raise
      rescue Errors::DoNotDisconnect
        # These exceptions are "expected" in the normal course of events, and
        # don't necessitate disconnecting.
        raise
      rescue Errors::ConnectionFailure
        disconnect
        if retry_on_failure
          # Maybe there was a hiccup -- try reconnecting one more time
          retry_on_failure = false
          retry
        else
          # Nope, we failed to connect twice. Flag the node as down and re-raise
          # the exception.
          down!
          raise
        end
      rescue
        # Looks like we got an unexpected error, so we'll clean up the connection
        # and re-raise the exception.
        disconnect
        raise $!.extend(Errors::SocketError)
      end
    ensure
      Threaded.end(:connection)
    end

    # Set a flag on the node for the duration of provided block so that an
    # exception is raised if the node is no longer the primary node.
    #
    # @example Ensure this node is primary.
    #   node.ensure_primary do
    #     #...
    #   end
    #
    # @return [ nil ] nil.
    #
    # @since 1.0.0
    def ensure_primary
      Threaded.begin(:ensure_primary)
      yield
    ensure
      Threaded.end(:ensure_primary)
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
      reply = process(Protocol::GetMore.new(database, collection, cursor_id, limit))
      raise Moped::Errors::CursorNotFound.new("GET MORE", cursor_id) if reply.cursor_not_found?
      reply
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
      !refreshed_at || refreshed_at < time
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
      Threaded.begin(:pipeline)
      begin
        yield
      ensure
        Threaded.end(:pipeline)
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
      @primary
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
      @arbiter
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
      @passive
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

      process(operation) do |reply|
        if reply.query_failed?
          if reply.unauthorized? && auth.has_key?(database)
            # If we got here, most likely this is the case of Moped
            # authenticating successfully against the node originally, but the
            # node has been reset or gone down and come back up. The most
            # common case here is a rs.stepDown() which will reinitialize the
            # connection. In this case we need to requthenticate and try again,
            # otherwise we'll just raise the error to the user.
            login(database, *auth[database])
            query(database, collection, selector, options)
          else
            raise Errors::QueryFailure.new(operation, reply.documents.first)
          end
        end
        reply
      end
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
          @refreshed_at = Time.now
          info = command("admin", ismaster: 1)
          primary = true   if info["ismaster"]
          secondary = true if info["secondary"]
          generate_peers(info)

          @primary, @secondary = primary, secondary
          @arbiter = info["arbiterOnly"]
          @passive = info["passive"]

          if !primary && Threaded.executing?(:ensure_primary)
            raise Errors::ReplicaSetReconfigured.new("#{inspect} is no longer the primary node.", {})
          elsif !primary && !secondary
            # not primary or secondary so mark it as down, since it's probably
            # a recovering node withing the replica set
            down!
          end
        rescue Timeout::Error
          @peers = []
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

    private

    def auth
      @auth ||= {}
    end

    def generate_peers(info)
      peers = []
      peers.push(info["primary"]) if info["primary"]
      peers.concat(info["hosts"]) if info["hosts"]
      peers.concat(info["passives"]) if info["passives"]
      peers.concat(info["arbiters"]) if info["arbiters"]
      @peers = peers.map { |peer| Node.new(peer, options) }.uniq
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

    def generate_peers(info)
      peers = []
      peers.push(info["primary"]) if info["primary"]
      peers.concat(info["hosts"]) if info["hosts"]
      peers.concat(info["passives"]) if info["passives"]
      peers.concat(info["arbiters"]) if info["arbiters"]
      @peers = peers.map{ |peer| discover(peer) }.uniq
    end

    def discover(peer)
      Node.new(peer, options).tap do |node|
        node.send(:auth).merge!(auth)
      end
    end

    def initialize_copy(_)
      @connection = nil
    end

    def connection
      @connection ||= Connection.new(ip_address, port, timeout, options)
    end

    def connected?
      connection.connected?
    end

    # Mark the node as down.
    #
    # Returns nothing.
    def down!
      @down_at = Time.new

      disconnect
    end

    # Connect to the node.
    #
    # Returns nothing.
    # Raises Moped::ConnectionError if the connection times out.
    # Raises Moped::ConnectionError if the server is unavailable.
    def connect
      connection.connect
      @down_at = nil
    end

    def process(operation, &callback)
      if Threaded.executing? :pipeline
        queue.push [operation, callback]
      else
        flush([[operation, callback]])
      end
    end

    def queue
      Threaded.stack(:pipelined_operations)
    end

    def flush(ops = queue)
      operations, callbacks = ops.transpose

      logging(operations) do
        ensure_connected do
          connection.write operations
          replies = connection.receive_replies(operations)

          replies.zip(callbacks).map do |reply, callback|
            callback ? callback[reply] : reply
          end.last
        end
      end
    ensure
      ops.clear
    end

    def logging(operations)
      instrument_start = (logger = Moped.logger) && logger.debug? && Time.new
      yield
    ensure
      log_operations(logger, operations, 1000 * (Time.new.to_f - instrument_start.to_f)) if instrument_start
    end

    def log_operations(logger, ops, duration_ms)
      prefix  = "  MOPED: #{resolved_address} "
      indent  = " "*prefix.length
      runtime = (" (%.4fms)" % duration_ms)

      if ops.length == 1
        logger.debug prefix + ops.first.log_inspect + runtime
      else
        first, *middle, last = ops

        logger.debug prefix + first.log_inspect
        middle.each { |m| logger.debug indent + m.log_inspect }
        logger.debug indent + last.log_inspect + runtime
      end
    end

    def resolve_address
      unless ip_address
        begin
          parse_address and true
        rescue SocketError
          if logger = Moped.logger
            logger.warn " MOPED: Could not resolve IP address for #{address}"
          end
          @down_at = Time.new
          false
        end
      else
        true
      end
    end

    def parse_address
      host, port = address.split(":")
      @port = (port || 27017).to_i
      @ip_address = ::Socket.getaddrinfo(host, nil, ::Socket::AF_INET, ::Socket::SOCK_STREAM).first[3]
      @resolved_address = "#{@ip_address}:#{@port}"
    end
  end
end
