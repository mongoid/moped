if ENV["COVERAGE"]
  require 'simplecov'

  SimpleCov.start do
    add_filter 'spec'

    add_group "BSON", 'lib/moped/bson'
    add_group "Protocol", 'lib/moped/protocol'
    add_group "Driver", 'lib/moped(?!/bson|/protocol)'
  end
end

require "java" if RUBY_PLATFORM == "java"
require "rspec"

$:.unshift((Pathname(__FILE__).dirname.parent + "lib").to_s)

require "benchmark"
require "fileutils"
require "tmpdir"
require "tempfile"
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

  config.after(:suite) do
    stop_mongo_server(31100)
    stop_mongo_server(31101)
    stop_mongo_server(31102)
  end

  unless Support::MongoHQ.replica_set_configured? || Support::MongoHQ.auth_node_configured?
    $stderr.puts Support::MongoHQ.message
  end
end

def start_mongo_server(port, extra_options=nil)
  stop_mongo_server(port)
  dbpath = File.join(Dir.tmpdir, port.to_s)
  FileUtils.mkdir_p(dbpath)
  `mongod --oplogSize 40 --noprealloc --smallfiles --port #{port} --dbpath #{dbpath} --logpath #{dbpath}/log --pidfilepath #{dbpath}/pid --fork #{extra_options}`

  sleep 0.1 while `echo 'db.runCommand({ping:1}).ok' | mongo --quiet --port #{port}`.chomp != "1"
end

def stop_mongo_server(port)
  dbpath = File.join(Dir.tmpdir, port.to_s)
  pidfile = File.join(dbpath, "pid")
  `kill #{File.read(pidfile).chomp}` if File.exists?(pidfile)
  FileUtils.rm_rf(dbpath)
end
