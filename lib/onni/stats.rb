# frozen_string_literal: true

require "onni/stats/purge"
require "onni/stats/sampler"
require "onni/stats/overview"
require "onni/stats/buffer"

module Onni
  module Stats
    module_function

    def record(name, enabled:)
      decision = Sampler.decide(name: name, enabled: enabled)
      return if decision == :skip

      Instrumenter.instrument("stats.record", name: name.to_s, enabled: enabled, weight: decision[:weight]) do
        if Onni.configuration.stats_buffer
          Buffer.add(name, enabled: enabled, weight: decision[:weight])
        else
          Onni.adapter.record_stat(name, enabled: enabled, weight: decision[:weight])
        end
      end
    rescue => error
      Rails.logger.warn("Onni stats failed: #{error.class}: #{error.message}") if defined?(Rails)
    end

    def for(name, period: "hour", from: 24.hours.ago, to: Time.current)
      Onni.adapter.stats_for(name, period: period, from: from, to: to)
    end

    def purge!(**kwargs)
      Instrumenter.instrument("stats.purge") do |payload|
        result = Purge.call(**kwargs)
        payload[:deleted] = result[:deleted]
        payload[:processed_count] = result[:processed_count]
        payload[:continued] = result[:continued]
        result
      end
    end

    def overview
      Overview.call
    end
  end
end
