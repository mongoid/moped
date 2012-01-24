require "benchmark"

$:.unshift "./"
$:.unshift "./lib"

require "lib/moped"

require "perf/helpers"
require "perf/setup"
require "perf/cases"

at_exit do
  Benchmark.bmbm do |x|
    Benchmark.cases.each do |name, block|
      x.report name, &block
    end
  end unless $!
end
