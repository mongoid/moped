require "java" if RUBY_PLATFORM == "java"
require "rspec"

$:.unshift((Pathname(__FILE__).dirname.parent + "lib").to_s)

require "moped"
require "support/mongohq"
require "support/replica_set_simulator"
require "support/stats"

RSpec.configure do |config|
  Support::Stats.install!

  config.include Support::ReplicaSetSimulator::Helpers, replica_set: true

  config.filter_run_excluding mongohq: ->(value) do
    return true if value == :replica_set && !Support::MongoHQ.replica_set_configured?
    return true if value == :auth && !Support::MongoHQ.auth_node_configured?
  end

  unless Support::MongoHQ.replica_set_configured? || Support::MongoHQ.auth_node_configured?
    $stderr.puts Support::MongoHQ.message
  end
end
