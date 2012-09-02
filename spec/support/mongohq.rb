module Support
  module MongoHQ
    extend self

    def replica_set_configured?
      ENV["MONGOHQ_REPL_PASS"]
    end

    def replica_set_seeds
      [ENV["MONGOHQ_REPL_1_URL"], ENV["MONGOHQ_REPL_2_URL"]]
    end

    def replica_set_credentials
      [ENV["MONGOHQ_REPL_USER"], ENV["MONGOHQ_REPL_PASS"]]
    end

    def replica_set_database
      ENV["MONGOHQ_REPL_NAME"]
    end

    def replica_set_session(auth = true)
      session = Moped::Session.new replica_set_seeds, database: replica_set_database
      session.login(*replica_set_credentials) if auth
      session
    end

    def auth_seeds
      [ENV["MONGOHQ_SINGLE_URL"]]
    end

    def auth_node_configured?
      ENV["MONGOHQ_SINGLE_PASS"]
    end

    def auth_credentials
      [ENV["MONGOHQ_SINGLE_USER"], ENV["MONGOHQ_SINGLE_PASS"]]
    end

    def auth_database
      ENV["MONGOHQ_SINGLE_NAME"]
    end

    def auth_session(auth = true)
      session = Moped::Session.new auth_seeds, database: auth_database
      session.login(*auth_credentials) if auth
      session
    end

    def ssl_replica_set_configured?
      ENV["MONGOHQ_REPL_SSL_PASS"]
    end

    def ssl_replica_set_seeds
      [ENV["MONGOHQ_REPL_SSL_1_URL"], ENV["MONGOHQ_REPL_SSL_2_URL"]]
    end

    def ssl_replica_set_credentials
      [ENV["MONGOHQ_REPL_SSL_USER"], ENV["MONGOHQ_REPL_SSL_PASS"]]
    end

    def ssl_replica_set_database
      ENV["MONGOHQ_REPL_SSL_NAME"]
    end

    def ssl_replica_set_session(auth = true)
      session = Moped::Session.new ssl_replica_set_seeds, database: ssl_replica_set_database, ssl: true
      session.login(*ssl_replica_set_credentials) if auth
      session
    end

    def message
      %Q{
      ---------------------------------------------------------------------
      Moped runs specs for authentication and replica sets against MongoHQ.

      If you want to run these specs and need the credentials, contact
      durran at gmail dot com.
      ---------------------------------------------------------------------
      }
    end

  end
end
