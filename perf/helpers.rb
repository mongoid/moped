require 'benchmark'

module Benchmark
  @cases = []
  @after_callbacks = []
  @before_callbacks = []

  class << self
    attr_reader :cases
    attr_reader :before_callbacks
    attr_reader :after_callbacks

    alias _measure measure

    def before(&block)
      before_callbacks << block
    end

    def after(&block)
      after_callbacks << block
    end

    def measure(*args, &block)
      before_callbacks.each &:call
      result = _measure(*args, &block)
      after_callbacks.each &:call
      result
    end
  end
end

def before(&block)
  Benchmark.before &block
end

def after(&block)
  Benchmark.after &block
end

def profile(name, &block)
  Benchmark.cases << [name, block]
end
