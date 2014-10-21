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

require "timeout"
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

  config.before :each do
    Moped::Connection::Manager.instance_variable_set(:@pools, {})
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

def start_mongo_server(port, extra_options=nil, clean_database_files=true)
  dbpath = File.join(Dir.tmpdir, "mongod-db", port.to_s)
  FileUtils.mkdir_p(dbpath)

  Timeout::timeout(10) do
    loop do
      `mongod --oplogSize 40 --noprealloc --smallfiles --port #{port} --dbpath #{dbpath} --logpath #{dbpath}/log --pidfilepath #{dbpath}/pid --fork #{extra_options}`
      sleep 1
      break if `echo 'db.runCommand({ping:1}).ok' | mongo --quiet --port #{port} 2>/dev/null`.chomp == "1"
    end
  end
end

def stop_mongo_server(port, clean_database_files=true)
  dbpath = File.join(Dir.tmpdir, "mongod-db", port.to_s)
  pidfile = File.join(dbpath, "pid")
  if File.exists?(pidfile)
    Timeout::timeout(10) do
      loop do
        `kill #{File.read(pidfile).chomp}`
        sleep 1
        break if `echo 'db.runCommand({ping:1}).ok' | mongo --quiet --port #{port} 2>/dev/null`.chomp != "1"
      end
    end
  end

  FileUtils.rm_rf(dbpath) if clean_database_files
end

def keyfile
  file = File.join(Dir.tmpdir, "mongod-db", "keyfile")
  return file if File.exists?(file)

  FileUtils.mkdir_p(File.dirname(file))
  File.open(file, "w", 0600) do |f|
    f.puts <<-EOF.gsub /^\s+/, ""
      SyrfEmAevWPEbgRZoZx9qZcZtJAAfd269da+kzi0H/7OuowGLxM3yGGUHhD379qP
      nw4X8TT2T6ecx6aqJgxG+biJYVOpNK3HHU9Dp5q6Jd0bWGHGGbgFHV32/z2FFiti
      EFLimW/vfn2DcJwTW29nQWhz2wN+xfMuwA6hVxFczlQlz5hIY0+a+bQChKw8wDZk
      rW1OjTQ//csqPbVA8fwB49ghLGp+o84VujhRxLJ+0sbs8dKoIgmVlX2kLeHGQSf0
      KmF9b8kAWRLwLneOR3ESovXpEoK0qpQb2ym6BNqP32JKyPA6Svb/smVONhjUI71f
      /zQ2ETX7ylpxIzw2SMv/zOWcVHBqIbdP9Llrxb3X0EsB6J8PeI8qLjpS94FyEddw
      ACMcAxbP+6BaLjXyJ2WsrEeqThAyUC3uF5YN/oQ9XiATqP7pDOTrmfn8LvryyzcB
      ByrLRTPOicBaG7y13ATcCbBdrYH3BE4EeLkTUZOg7VzvRnATvDpt0wOkSnbqXow8
      GQ6iMUgd2XvUCuknQLD6gWyoUyHiPADKrLsgnd3Qo9BPxYJ9VWSKB4phK3N7Bic+
      BwxlcpDFzGI285GR4IjcJbRRjjywHq5XHOxrJfN+QrZ/6wy6yu2+4NTPj+BPC5iX
      /dNllTEyn7V+pr6FiRv8rv8RcxJgf3nfn/Xz0t2zW2olcalEFxwKKmR20pZxPnSv
      Kr6sVHEzh0mtA21LoK5G8bztXsgFgWU7hh9z8UUo7KQQnDfyPb6k4xroeeQtWBNo
      TZF1pI5joLytNSEtT+BYA5wQSYm4WCbhG+j7ipcPIJw6Un4ZtAZs0aixDfVE0zo0
      w2FWrYH2dmmCMbz7cEXeqvQiHh9IU/hkTrKGY95STszGGFFjhtS2TbHAn2rRoFI0
      VwNxMJCC+9ZijTWBeGyQOuEupuI4C9IzA5Gz72048tpZ0qMJ9mOiH3lZFtNTg/5P
      28Td2xzaujtXjRnP3aZ9z2lKytlr
    EOF
  end
  file
end

def setup_replicaset_environment(with_authentication=false, replica_set_name='dev')
  status = servers_status(with_authentication).select{|st| st == "PRIMARY" || st == "SECONDARY"}
  has_admin = has_user_admin?(with_authentication)
  unless status.count == 3 && status.all?{|st| st == "PRIMARY" || st == "SECONDARY"} && (with_authentication ? has_admin : !has_admin)
    stop_mongo_server(31101)
    stop_mongo_server(31100)
    stop_mongo_server(31102)

    options = with_authentication ? "--replSet #{replica_set_name} --keyFile #{keyfile} --auth"  : "--replSet #{replica_set_name}"
    start_mongo_server(31100, options)
    start_mongo_server(31101, options)
    start_mongo_server(31102, options)

    Timeout::timeout(90) do
      sleep 5 while `echo "rs.initiate({_id : '#{replica_set_name}', 'members' : [{_id:0, host:'127.0.0.1:31100'},{_id:1, host:'127.0.0.1:31101'},{_id:2, host:'127.0.0.1:31102'}]}).ok"  | mongo --quiet --port 31100 2>/dev/null`.chomp != "1"
      sleep 1 while !servers_status(false).all?{|st| st == "PRIMARY" || st == "SECONDARY"}
    end

    master = `echo 'db.isMaster().primary' | mongo --quiet --port 31100 2>/dev/null`.chomp

    auth_credentials = ""
    if with_authentication
      `echo "
      use admin;
      db.addUser('admin', 'admin_pwd');
      " | mongo #{master} 2>/dev/null`

      auth_credentials = "-u admin -p admin_pwd --authenticationDatabase admin"
    end

    `echo "
    use test_db;
    db.addUser('common', 'common_pwd');
    db.foo.ensureIndex({name:1}, {unique:1});
    " | mongo #{master} #{auth_credentials} 2>/dev/null`
  end
end

def servers_status(with_authentication)
  auth = has_user_admin?(with_authentication) ? "-u admin -p admin_pwd --authenticationDatabase admin" : ""
  `echo 'rs.status().members[0].stateStr + "|" + rs.status().members[1].stateStr + "|" + rs.status().members[2].stateStr' | mongo --quiet --port 31100 #{auth} 2>/dev/null`.chomp.split("|")
end

def has_user_admin?(with_authentication)
  auth = with_authentication ? "-u admin -p admin_pwd --authenticationDatabase admin" : ""
  `echo 'db.getSisterDB("admin").getUser("admin").user' | mongo --quiet --port 31100 #{auth} 2>/dev/null`.chomp   == "admin"
end
