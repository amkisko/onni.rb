# frozen_string_literal: true

require "onni/stats/sampler"

module Onni
  class Configuration
    CONCURRENCY_MODES = %i[mutex none].freeze

    attr_accessor :features_path, :cache, :cache_ttl, :stats_enabled,
      :stats_sampler, :stats_ignore, :stats_scale_sampled_hits, :stats_buffer,
      :request_preload, :adapter, :logger, :instrumenter
    attr_reader :stats_sample_rate, :concurrency, :stats_retention

    def initialize
      @features_path = "config/features.yml"
      @cache = nil
      @cache_ttl = 15 * 60
      @stats_enabled = true
      @stats_sample_rate = 1.0
      # Optional callable `{name:, shown:} -> rate|bool|nil` (nil falls back to stats_sample_rate).
      @stats_sampler = nil
      # Feature keys that never write hit buckets.
      @stats_ignore = []
      # When true, a kept sample increments by ~1/rate so totals estimate full traffic.
      @stats_scale_sampled_hits = true
      # When true, hit stats coalesce in the fiber-local buffer until Onni.flush_stats! / reset_request!.
      @stats_buffer = false
      # When true, RequestLifecycle middleware calls Onni.preload! at request start.
      @request_preload = false
      # How long hourly hit buckets are kept. Used by Onni::Stats::Purge / the cleanup job.
      @stats_retention = 90 * 86_400
      # :mutex covers threads and fibers on Ruby 3.4+; :none skips locking.
      @concurrency = :mutex
      @adapter = :memory
    end

    def stats_retention=(value)
      valid = case value
      when nil then true
      when Integer then value >= 0
      else false
      end
      unless valid
        raise ArgumentError, "Stats retention must be nonnegative integer seconds or nil"
      end

      @stats_retention = value
    end

    def stats_sample_rate=(value)
      @stats_sample_rate = Stats::Sampler.coerce_rate(value)
    end

    def concurrency=(value)
      mode = value.to_sym
      unless CONCURRENCY_MODES.include?(mode)
        raise ArgumentError, "Unknown Onni concurrency #{value.inspect} (expected #{CONCURRENCY_MODES.join(", ")})"
      end

      @concurrency = mode
      Sync.reset! if defined?(Onni::Sync)
      Onni.reset_adapter! if Onni.respond_to?(:reset_adapter!)
    end
  end
end
