module Moped
  module Protocol

    # The +Moped::Protocol::Commands+ namespace contains classes for
    # specific commands, such as authentication, to execute on a database.
    module Commands
    end
  end
end

require "moped/protocol/commands/authenticate"
