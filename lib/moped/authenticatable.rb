# encoding: utf-8
module Moped

  # Provides behaviour to nodes around authentication.
  #
  # @since 2.0.0
  module Authenticatable

    # Apply authentication credentials.
    #
    # @example Apply the authentication credentials.
    #   node.apply_credentials({ "moped_test" => [ "user", "pass" ]})
    #
    # @param [ Hash ] credentials The authentication credentials in the form:
    #   { database_name: [ user, password ]}
    #
    # @return [ Object ] The authenticated object.
    #
    # @since 2.0.0
    def apply_credentials(logins)
      unless credentials == logins
        logouts = credentials.keys - logins.keys
        logouts.each do |database|
          logout(database)
        end
        logins.each do |database, (username, password)|
          unless credentials[database] == [ username, password ]
            login(database, username, password)
          end
        end
      end
      self
    end

    # Get the applied credentials.
    #
    # @example Get the applied credentials.
    #   node.credentials
    #
    # @return [ Hash ] The credentials.
    #
    # @since 2.0.0
    def credentials
      @credentials ||= {}
    end

    # Login the user to the provided database with the supplied password.
    #
    # @example Login the user to the database.
    #   node.login("moped_test", "user", "pass")
    #
    # @param [ String ] database The database name.
    # @param [ String ] username The username.
    # @param [ String ] password The password.
    #
    # @raise [ Errors::AuthenticationFailure ] If the login failed.
    #
    # @return [ Array ] The username and password.
    #
    # @since 2.0.0
    def login(database, username, password)
      getnonce = Protocol::Command.new(database, getnonce: 1)
      self.write([getnonce])
      reply = self.receive_replies([getnonce]).first
      if getnonce.failure?(reply)
        return
      end
      result = getnonce.results(reply)

      authenticate = Protocol::Commands::Authenticate.new(database, username, password, result["nonce"])
      self.write([ authenticate ])
      document = self.read.documents.first

      raise Errors::AuthenticationFailure.new(authenticate, document) unless document["ok"] == 1
      credentials[database] = [username, password]
    end

    # Logout the user from the provided database.
    #
    # @example Logout from the provided database.
    #   node.logout("moped_test")
    #
    # @param [ String ] database The database name.
    #
    # @return [ Array ] The username and password.
    #
    # @since 2.0.0
    def logout(database)
      command = Protocol::Command.new(database, logout: 1)
      self.write([command])
      reply = self.receive_replies([command]).first
      if command.failure?(reply)
        return
      end
      credentials.delete(database)
    end
  end
end
