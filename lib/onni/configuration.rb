# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/numeric/time"
require "onni/stats/sampler"

module Onni
  class Configuration
    CONCURRENCY_MODES = %i[mutex none].freeze

    attr_accessor :features_path, :cache, :cache_ttl, :stats_enabled, :stats_retention,
      :stats_sampler, :stats_ignore, :stats_scale_sampled_hits, :stats_buffer,
      :request_preload, :adapter, :admin_authorized
    attr_reader :stats_sample_rate, :concurrency

    def initialize
      @features_path = nil
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
      @stats_retention = 90.days
      # :mutex covers threads and fibers on Ruby 3.4+; :none skips locking.
      @concurrency = :mutex
      @adapter = :memory
      # Who may open the Onni ActiveAdmin dashboard (not application authorization).
      # Called with the ActiveAdmin page controller as receiver (instance_exec).
      @admin_authorized = -> { true }
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
