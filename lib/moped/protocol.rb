module Moped #:nodoc:

  # The +Moped::Protocol+ namespace contains convenience classes for
  # building all of the possible messages defined in the Mongo Wire Protocol.
  module Protocol
  end
end

require "moped/protocol/message"

require "moped/protocol/delete"
require "moped/protocol/get_more"
require "moped/protocol/insert"
require "moped/protocol/kill_cursors"
require "moped/protocol/query"
require "moped/protocol/reply"
require "moped/protocol/update"

require "moped/protocol/command"
require "moped/protocol/commands"
