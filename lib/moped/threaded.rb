module Moped

  # This module contains logic for easy access to objects that have a lifecycle
  # on the current thread.
  #
  # Extracted from Mongoid's +Threaded+ module.
  #
  # @api private
  module Threaded
    extend self

    # Begin a thread-local stack for +name+.
    def begin(name)
      stack(name).push true
    end

    # @return [Boolean] whether the stack is being executed
    def executing?(name)
      !stack(name).empty?
    end

    # End the thread-local stack for +name+.
    def end(name)
      stack(name).pop
    end

    # @return [Array] a named, thread-local stack.
    def stack(name)
      Thread.current["[moped]:#{name}-stack"] ||= []
    end
  end
end
