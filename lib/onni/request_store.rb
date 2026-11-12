# frozen_string_literal: true

module Onni
  # Fiber-local request scratch (gates preload, stats buffer).
  # Hosts clear via Onni.reset_request! at request end.
  module RequestStore
    GATES_KEY = :onni_request_gates
    STATS_KEY = :onni_stats_buffer

    module_function

    def gates
      Fiber[GATES_KEY]
    end

    def gates=(value)
      Fiber[GATES_KEY] = value
    end

    def stats_buffer
      Fiber[STATS_KEY]
    end

    def stats_buffer=(value)
      Fiber[STATS_KEY] = value
    end

    def clear!
      Fiber[GATES_KEY] = nil
      Fiber[STATS_KEY] = nil
    end
  end
end
