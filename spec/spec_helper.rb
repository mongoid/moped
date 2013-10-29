if ENV["CI"]
  require "simplecov"
  require "coveralls"
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter "spec"
  end
end

require "java" if RUBY_PLATFORM == "java"
require "rspec"

$:.unshift((Pathname(__FILE__).dirname.parent + "lib").to_s)

require "moped"
require "support/examples"
require "support/mongohq"
require "support/replica_set_simulator"
require "support/stats"

# Log to a StringIO instance to make sure no exceptions are rasied by our
# logging code.
Moped.logger = Logger.new(StringIO.new, Logger::DEBUG)

RSpec.configure do |config|
  Support::Stats.install!
  Support::ReplicaSetSimulator.configure config

  config.filter_run_excluding mongohq: ->(value) do
    return true if value == :replica_set_ssl# && !Support::MongoHQ.ssl_replica_set_configured?
    return true if value == :replica_set && !Support::MongoHQ.replica_set_configured?
    return true if value == :auth && !Support::MongoHQ.auth_node_configured?
  end

  config.before :each do
    Moped::Connection::Manager.instance_variable_set(:@pools, {})
  end

  unless Support::MongoHQ.replica_set_configured? || Support::MongoHQ.auth_node_configured?
    $stderr.puts Support::MongoHQ.message
  end
end
