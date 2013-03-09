# encoding: utf-8
module Moped

  # Provides common behavior around executing a thread local stack safely.
  #
  # @since 2.0.0
  module Executable

    # Given the name of a thread local stack, ensure that execution happens by
    # starting and ending the stack execution cleanly.
    #
    # @example Ensure execution of a pipeline.
    #   execute(:pipeline) do
    #     yield(self)
    #   end
    #
    # @param [ Symbol ] name The name of the stack.
    #
    # @return [ Object ] The result of the yield.
    #
    # @since 2.0.0
    def execute(name)
      Threaded.begin_execution(name)
      begin
        yield(self)
      ensure
        Threaded.end_execution(name)
      end
    end

    # Are we currently executing a stack on the thread?
    #
    # @example Are we executing a pipeline?
    #   executing?(:pipeline)
    #
    # @param [ Symbol ] name The name of the stack.
    #
    # @return [ true, false ] If we are executing the stack.
    #
    # @since 2.0.0
    def executing?(name)
      Threaded.executing?(name)
    end
  end
end
