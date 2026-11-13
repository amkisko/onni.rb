# frozen_string_literal: true

require "onni/stats/purge"
require "onni/stats/sampler"
require "onni/stats/overview"
require "onni/stats/buffer"

module Onni
  module Stats
    module_function

    def record(name, shown:, record_stats: nil, definition: Policy::EMPTY, gates: nil)
      return unless Onni.configuration.stats_enabled
      return if record_stats == false

      policy = Policy.effective(definition, gates)
      return unless Policy.enabled?(policy, record_stats)

      decision = Sampler.decide(name: name, shown: shown, sample_rate: policy["sample_rate"])
      return if decision == :skip

      Instrumenter.instrument("stats.record", name: name.to_s, shown: shown, weight: decision[:weight]) do
        if Onni.configuration.stats_buffer
          Buffer.add(name, shown: shown, weight: decision[:weight])
        else
          Onni.adapter.record_stat(name, shown: shown, weight: decision[:weight])
        end
      end
    rescue => error
      Onni.configuration.logger&.warn("Onni stats failed: #{error.class}: #{error.message}")
    end

    def for(name, period: "hour", from: Time.now - 86_400, to: Time.now)
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
