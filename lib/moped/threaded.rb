module Moped

  # This module contains logic for easy access to objects that have a lifecycle
  # on the current thread.
  #
  # Extracted from Mongoid's +Threaded+ module.
  #
  # @api private
  module Threaded
    extend self

    # Begin entry into a named thread local stack.
    #
    # @example Begin entry into the stack.
    #   Threaded.begin(:create)
    #
    # @param [ String ] name The name of the stack.
    #
    # @return [ true ] True.
    #
    # @since 1.0.0
    def begin(name)
      stack(name).push(true)
    end

    # Are in the middle of executing the named stack
    #
    # @example Are we in the stack execution?
    #   Threaded.executing?(:create)
    #
    # @param [ Symbol ] name The name of the stack.
    #
    # @return [ true ] If the stack is being executed.
    #
    # @since 1.0.0
    def executing?(name)
      !stack(name).empty?
    end

    # Exit from a named thread local stack.
    #
    # @example Exit from the stack.
    #   Threaded.end(:create)
    #
    # @param [ Symbol ] name The name of the stack
    #
    # @return [ true ] True.
    #
    # @since 1.0.0
    def end(name)
      stack(name).pop
    end

    # Get the named stack.
    #
    # @example Get a stack by name
    #   Threaded.stack(:create)
    #
    # @param [ Symbol ] name The name of the stack
    #
    # @return [ Array ] The stack.
    #
    # @since 1.0.0
    def stack(name)
      stacks = (Thread.current[:__moped_threaded_stacks__] ||= {})
      stacks[name] ||= []
    end
  end
end
