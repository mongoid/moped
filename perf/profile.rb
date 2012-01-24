require "benchmark"
require "perftools"

$:.unshift "./"
$:.unshift "./lib"

require "moped"
require "perf/helpers"

begin
  require "em-synchrony"
  $em = true
rescue LoadError
  $em = false
end

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

at_exit do
  Benchmark.cases.each do |name, block|
    profile_name = name.downcase.gsub /\W/, '_'

    Benchmark.before_callbacks.each &:call
    without_gc do
      PerfTools::CpuProfiler.start(
        "perf/results/#{profile_name}.profile",
        &block
      )
    end
    Benchmark.after_callbacks.each &:call
  end

  Dir.glob("perf/results/*.profile") do |profile|
    puts "Generating #{profile}.pdf..."
    `bundle exec pprof.rb --pdf #{profile} > #{profile}.pdf`
  end unless $!
end

with_eventmachine do
  require "perf/setup"
  require "perf/cases"
end
