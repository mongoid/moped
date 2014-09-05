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

require "benchmark"
require "fileutils"
require "tmpdir"
require "popen4"
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

  config.after(:suite) do
    stop_mongo_server(31100)
  end

  unless Support::MongoHQ.replica_set_configured? || Support::MongoHQ.auth_node_configured?
    $stderr.puts Support::MongoHQ.message
  end
end


def start_mongo_server(port, extra_options=nil)
  stop_mongo_server(port)
  dbpath = File.join(Dir.tmpdir, port.to_s)
  FileUtils.mkdir_p(dbpath)
  POpen4::popen4("mongod --oplogSize 40 --noprealloc --smallfiles --port #{port} --dbpath #{dbpath} --logpath #{dbpath}/log --pidfilepath #{dbpath}/pid --fork #{extra_options}") do |stdout, stderr, stdin, pid|
    error_message = stderr.read.strip unless stderr.eof
    raise StandardError.new error_message unless error_message.nil?
  end

  while `echo 'db.runCommand({ping:1}).ok' | mongo --quiet --port #{port}`.chomp != "1"
    sleep 0.1
  end
end

def stop_mongo_server(port)
  dbpath = File.join(Dir.tmpdir, port.to_s)
  pidfile = File.join(dbpath, "pid")
  `kill #{File.read(pidfile).chomp}` if File.exists?(pidfile)
  FileUtils.rm_rf(dbpath)
end
