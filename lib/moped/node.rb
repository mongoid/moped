module Moped
  class Node

    attr_reader :address
    attr_reader :resolved_address
    attr_reader :ip_address
    attr_reader :port

    attr_reader :peers
    attr_reader :timeout

    def initialize(address)
      @address = address

      host, port = address.split(":")
      @ip_address = ::Socket.getaddrinfo(host, nil, ::Socket::AF_INET, ::Socket::SOCK_STREAM).first[3]
      @port = port.to_i
      @resolved_address = "#{@ip_address}:#{@port}"

      @timeout = 5
    end

    def command(database, cmd, options = {})
      operation = Protocol::Command.new(database, cmd, options)

      process(operation) do |reply|
        result = reply.documents[0]

        raise Errors::OperationFailure.new(
          operation, result
        ) if result["ok"] != 1 || result["err"] || result["errmsg"]

        result
      end
    end

    def kill_cursors(cursor_ids)
      process Protocol::KillCursors.new(cursor_ids)
    end

    def get_more(database, collection, cursor_id, limit)
      process Protocol::GetMore.new(database, collection, cursor_id, limit)
    end

    def remove(database, collection, selector, options = {})
      process Protocol::Delete.new(database, collection, selector, options)
    end

    def update(database, collection, selector, change, options = {})
      process Protocol::Update.new(database, collection, selector, change, options)
    end

    def insert(database, collection, documents)
      process Protocol::Insert.new(database, collection, documents)
    end

    def query(database, collection, selector, options = {})
      operation = Protocol::Query.new(database, collection, selector, options)

      process operation do |reply|
        if reply.flags.include? :query_failure
          raise Errors::QueryFailure.new(operation, reply.documents.first)
        end

        reply
      end
    end

    # @return [true/false] whether the node needs to be refreshed.
    def needs_refresh?(time)
      !@refreshed_at || @refreshed_at < time
    end

    def primary?
      @primary
    end

    def secondary?
      @secondary
    end

    # Refresh information about the node, such as it's status in the replica
    # set and it's known peers.
    #
    # Returns nothing.
    # Raises Errors::ConnectionFailure if the node cannot be reached
    # Raises Errors::ReplicaSetReconfigured if the node is no longer a primary node and
    #   refresh was called within an +#ensure_primary+ block.
    def refresh
      info = command "admin", ismaster: 1

      @refreshed_at = Time.now
      primary = true if info["ismaster"]
      secondary = true if info["secondary"]

      peers = []
      peers.push info["primary"] if info["primary"]
      peers.concat info["hosts"] if info["hosts"]
      peers.concat info["passives"] if info["passives"]
      peers.concat info["arbiters"] if info["arbiters"]

      @peers = peers.map { |peer| Node.new(peer) }
      @primary, @secondary = primary, secondary

      if !primary && Threaded.executing?(:ensure_primary)
        raise Errors::ReplicaSetReconfigured, "#{inspect} is no longer the primary node."
      end
    end

    attr_reader :down_at

    def down?
      @down_at
    end

    # Set a flag on the node for the duration of provided block so that an
    # exception is raised if the node is no longer the primary node.
    #
    # Returns nothing.
    def ensure_primary
      Threaded.begin :ensure_primary
      yield
    ensure
      Threaded.end :ensure_primary
    end

    # Yields the block if a connection can be established, retrying when a
    # connection error is raised.
    #
    # @raises ConnectionFailure when a connection cannot be established.
    def ensure_connected
      # Don't run the reconnection login if we're already inside an
      # +ensure_connected+ block.
      return yield if Threaded.executing? :connection
      Threaded.begin :connection

      retry_on_failure = true

      begin
        connect unless connected?
        yield
      rescue Errors::ReplicaSetReconfigured
        # Someone else wrapped this in an #ensure_primary block, so let the
        # reconfiguration exception bubble up.
        raise
      rescue Errors::OperationFailure, Errors::AuthenticationFailure, Errors::QueryFailure
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
      Threaded.end :connection
    end

    def pipeline
      Threaded.begin :pipeline

      begin
        yield
      ensure
        Threaded.end :pipeline
      end

      flush unless Threaded.executing? :pipeline
    end

    def apply_auth(credentials)
      unless auth == credentials
        logouts = auth.keys - credentials.keys

        logouts.each do |database|
          logout database
        end

        credentials.each do |database, (username, password)|
          login(database, username, password) unless auth[database] == [username, password]
        end
      end

      self
    end

    def ==(other)
      resolved_address == other.resolved_address
    end
    alias eql? ==

    def hash
      [ip_address, port].hash
    end

    private

    def auth
      @auth ||= {}
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

    def initialize_copy(_)
      @connection = nil
    end

    def connection
      @connection ||= Connection.new
    end

    def disconnect
      auth.clear
      connection.disconnect
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
      connection.connect ip_address, port, timeout
      @down_at = nil

      refresh
    rescue Timeout::Error
      raise Errors::ConnectionFailure, "Timed out connection to Mongo on #{address}"
    rescue Errno::ECONNREFUSED
      raise Errors::ConnectionFailure, "Could not connect to Mongo on #{address}"
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
      log_operations(logger, operations, Time.new - instrument_start) if instrument_start && !$!
    end

    def log_operations(logger, ops, duration)
      prefix  = "  MOPED: #{address} "
      indent  = " "*prefix.length
      runtime = (" (%.1fms)" % duration)

      if ops.length == 1
        logger.debug prefix + ops.first.log_inspect + runtime
      else
        first, *middle, last = ops

        logger.debug prefix + first.log_inspect
        middle.each { |m| logger.debug indent + m.log_inspect }
        logger.debug indent + last.log_inspect + runtime
      end
    end

  end
end
