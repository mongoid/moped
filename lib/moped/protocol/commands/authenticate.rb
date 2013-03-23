module Moped
  module Protocol
    module Commands

      # Implementation of the authentication command for Mongo. See:
      # http://www.mongodb.org/display/DOCS/Implementing+Authentication+in+a+Driver
      # for details.
      #
      # @example
      #   socket.write Command.new :admin, getnonce: 1
      #   reply = Reply.deserialize socket
      #   socket.write Authenticate.new :admin, "username", "password",
      #     reply.documents[0]["nonce"]
      #   Reply.deserialize(socket).documents[0]["ok"] # => 1.0
      class Authenticate < Command

        # Create a new authentication command.
        #
        # @param [String] database the database to authenticate against
        # @param [String] username
        # @param [String] password
        # @param [String] nonce the nonce returned from running the getnonce
        # command.
        def initialize(database, username, password, nonce)
          super(database, build_auth_command(username, password, nonce))
        end

        # @param [String] username
        # @param [String] password
        # @param [String] nonce
        # @return [String] the mongo digest of the username, password, and
        # nonce.
        def digest(username, password, nonce)
          Digest::MD5.hexdigest(
            nonce + username + Digest::MD5.hexdigest(username + ":mongo:" + password)
          )
        end

        # @param [String] username
        # @param [String] password
        # @param [String] nonce
        def build_auth_command(username, password, nonce)
          {
            authenticate: 1,
            user: username,
            nonce: nonce,
            key: digest(username, password, nonce)
          }
        end
      end
    end
  end
end
