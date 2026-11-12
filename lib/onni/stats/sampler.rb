# frozen_string_literal: true

module Onni
  module Stats
    # Sampling decision for hit stats:
    # - float rate in 0.0..1.0 with clamp
    # - skip Random when rate is 1.0
    # - optional per-evaluation sampler callable
    # - ignore list for noisy keys
    # - optional inverse-rate weight so stored counters estimate full traffic
    module Sampler
      MAX_WEIGHT = 1_000_000

      module_function

      def decide(name:, enabled:)
        config = Onni.configuration
        return :skip unless config.stats_enabled
        return :skip if ignored?(name, config)

        rate = coerce_rate(rate_for(name: name, enabled: enabled, config: config))
        return :skip if rate <= 0.0
        return {record: true, weight: 1} if rate >= 1.0
        return :skip unless Random.rand < rate

        weight = config.stats_scale_sampled_hits ? weight_for(rate) : 1
        {record: true, weight: weight}
      end

      def coerce_rate(rate)
        case rate
        when true then 1.0
        when false, nil then 0.0
        else
          value = rate.to_f
          value.clamp(0.0, 1.0)
        end
      end

      def weight_for(rate)
        return 1 if rate <= 0.0

        (1.0 / rate).round.clamp(1, MAX_WEIGHT)
      end

      def rate_for(name:, enabled:, config:)
        if config.stats_sampler
          sampled = config.stats_sampler.call({name: name.to_s, enabled: enabled})
          return sampled unless sampled.nil?
        end

        config.stats_sample_rate
      end
      private_class_method :rate_for

      def ignored?(name, config)
        Array(config.stats_ignore).any? { |key| key.to_s == name.to_s }
      end
      private_class_method :ignored?
    end
  end
end
