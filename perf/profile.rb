require "benchmark"
require "bundler/setup"
Bundler.require
require "./lib/moped"

begin
  require "em-synchrony"
  $em = true
rescue LoadError
  $em = false
end

# HELPERS #

@before_callbacks = []
@after_callbacks = []

def without_gc
  GC.disable
  yield
  GC.enable
  GC.start
end

def with_eventmachine
  if $em
    EM.synchrony do
      yield
      EM.stop
    end
  else
    yield
  end
end

def after(&block)
  @after_callbacks << block
end

def before(&block)
  @before_callbacks << block
end

def profile(description, &block)
  puts "[ #{description} ]"

  @before_callbacks.each &:call
  without_gc do
    puts Benchmark.measure(&block)
  end
  @after_callbacks.each &:call

  profile_name = description.downcase.gsub /\W/, '_'

  @before_callbacks.each &:call
  without_gc do
    PerfTools::CpuProfiler.start(
      "perf/results/#{profile_name}.profile",
      &block
    )
  end
  @after_callbacks.each &:call
end

at_exit do
  Dir.glob("perf/results/*.profile") do |profile|
    puts "Generating #{profile}.pdf..."
    `bundle exec pprof.rb --pdf #{profile} > #{profile}.pdf`
  end unless $!
end

# SETUP / TEARDOWN #

session = Moped::Session.new "127.0.0.1:27017", database: "moped_test"

with_eventmachine do
  session.with database: "system" do |system|
    system[:indexes].insert(
      name: "moped_test_people_id",
      ns: "moped_test.people",
      key: [[:id, 1]]
    )
  end

  before do
    session[:people].find.remove_all
  end

  after do
    session[:people].find.remove_all
  end

  # CASES #

  profile "Insert 1,000 documents serially (no safe mode)" do
    1_000.times do
      session[:people].insert({})
    end
  end

  profile "Insert 10,000 documents serially (no safe mode)" do
    10_000.times do
      session[:people].insert({})
    end
  end

  profile "Insert 10,000 documents serially (safe mode)" do
    session.with(safe: true) do
      10_000.times do
        session[:people].insert({})
      end
    end
  end

  profile "Query 1,000 normal documents (100 times)" do
    session[:people].insert(1000.times.map do
      { _id: Moped::BSON::ObjectId.new,
        name: "John",
        created_at: Time.now,
        comment: "a"*200 }
    end)
    100.times do
      session[:people].find.each { |doc| }
    end
  end

  profile "Query 1,000 large documents (100 times)" do
    session[:people].insert(1000.times.map { { name: "John", data: "a"*10000 }})
    100.times do
      session[:people].find.each { |doc| }
    end
  end
end
