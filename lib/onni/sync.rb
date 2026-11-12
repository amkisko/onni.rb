# frozen_string_literal: true

module Onni
  # Configurable mutual exclusion for shared in-process state.
  # On Ruby 3.4+, Mutex ownership is per Fiber, so :mutex covers threads and fibers.
  # Do not Fiber.yield inside a synchronize block.
  module Sync
    BOOTSTRAP = Mutex.new

    class NullLock
      def synchronize
        yield
      end
    end

    module_function

    def new_lock
      case Onni.configuration.concurrency
      when :mutex then Mutex.new
      when :none then NullLock.new
      else
        raise ArgumentError, "Unknown Onni concurrency #{Onni.configuration.concurrency.inspect}"
      end
    end

    def synchronize(&block)
      shared_lock.synchronize(&block)
    end

    def reset!
      BOOTSTRAP.synchronize { @shared_lock = nil }
    end

    def shared_lock
      lock = @shared_lock
      return lock if lock

      BOOTSTRAP.synchronize { @shared_lock ||= new_lock }
    end
    private_class_method :shared_lock
  end
end
