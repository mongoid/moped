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
      begin_execution(name)
      begin
        yield(self)
      ensure
        end_execution(name)
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
      !stack(name).empty?
    end

    private

    # Begin entry into a named thread local stack.
    #
    # @api private
    #
    # @example Begin entry into the stack.
    #   executable.begin_execution(:create)
    #
    # @param [ String ] name The name of the stack.
    #
    # @return [ true ] True.
    #
    # @since 1.0.0
    def begin_execution(name)
      stack(name).push(true)
    end

    # Exit from a named thread local stack.
    #
    # @api private
    #
    # @example Exit from the stack.
    #   executable.end_execution(:create)
    #
    # @param [ Symbol ] name The name of the stack
    #
    # @return [ true ] True.
    #
    # @since 1.0.0
    def end_execution(name)
      stack(name).pop
    end

    # Get the named stack.
    #
    # @api private
    #
    # @example Get a stack by name
    #   executable.stack(:create)
    #
    # @param [ Symbol ] name The name of the stack
    #
    # @return [ Array ] The stack.
    #
    # @since 1.0.0
    def stack(name)
      stacks = (Thread.current[:"moped-stacks"] ||= {})
      stacks[name] ||= []
    end
  end
end
