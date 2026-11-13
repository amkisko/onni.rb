# frozen_string_literal: true

require "time"
require "json"
require "objspace"
require "securerandom"

module Onni
  module Store
    CACHE_KEY_PREFIX = "onni/gates/v4/"

    @cache_states = ObjectSpace::WeakKeyMap.new

    module_function

    def visible?(name, actor = nil, record_stats: nil)
      Stats::Policy.validate_option!(record_stats)
      definition = Registry.definition(name)
      return false unless definition

      gates = cached_gates(name)
      result = Settings.powered?(gates, definition) && matches?(name, actor, definition, gates)
      Stats.record(name, shown: result, record_stats: record_stats, definition: definition, gates: gates) unless record_stats == false
      result
    end

    def power_state(name)
      definition = Registry.definition(name)
      return unless definition

      Settings.power_state(cached_gates(name), definition)
    end

    def variant(name, actor = nil, record_stats: nil)
      Stats::Policy.validate_option!(record_stats)
      definition = Registry.definition(name)
      return unless definition

      gates = cached_gates(name)
      result = assignment(name, actor, definition, gates)
      Stats.record(name, shown: !result.nil?, record_stats: record_stats, definition: definition, gates: gates) unless record_stats == false
      result
    end

    def assignment(name, actor, definition, gates)
      return if actor.nil?
      return unless Settings.powered?(gates, definition)
      return unless Settings.type(definition) == "experiment"

      weights = Settings.variants(definition, gates)
      matched = weights.values.sum.positive? && matches?(name, actor, definition, gates)
      Actor.variant_for(actor, name, weights) if matched
    end
    private_class_method :assignment

    def matches?(name, actor, definition, gates)
      return false if expired?(definition)
      return false unless audience_matches?(name, actor, definition, gates)

      Conditions.met?(name, actor, definition: definition)
    end
    private_class_method :matches?

    def audience_matches?(name, actor, definition, gates)
      Audience.matches?(name, actor, Settings.filters(definition, gates))
    end
    private_class_method :audience_matches?

    def expired?(definition)
      raw = definition["expires_at"]
      return false if raw.nil? || raw.to_s.empty?

      deadline = definition["expires_at_time"]
      if deadline.nil?
        begin
          deadline = Time.parse(raw.to_s).utc
        rescue ArgumentError, TypeError
          return true
        end
      end
      deadline < Time.now.utc
    rescue ArgumentError, TypeError
      true
    end
    private_class_method :expired?

    def cached_gates(name)
      key = name.to_s
      preloaded = RequestStore.gates
      return GateSnapshot.wrap(preloaded[key]) if preloaded&.key?(key)

      cache = Onni.configuration.cache
      return read_gates(key) unless cache

      cache.fetch(cache_key(key), expires_in: Onni.configuration.cache_ttl) do
        read_gates(key)
      end
    end
    private_class_method :cached_gates

    def read_gates(name)
      adapter = Onni.adapter
      gates = adapter.respond_to?(:gates_snapshot_for) ? adapter.gates_snapshot_for(name) : adapter.gates_for(name)
      GateSnapshot.wrap(gates)
    end
    private_class_method :read_gates

    def bust_cache!(name)
      key = name.to_s
      cache = Onni.configuration.cache
      old_key = cache_key(key, advance: true)
      if cache
        begin
          cache.delete(old_key)
        rescue => error
          Onni.configuration.logger&.warn("Onni cache cleanup failed: #{error.class}")
        end
      end
      RequestStore.gates&.delete(key)
    end

    def cache_key(name, advance: false)
      adapter = Onni.adapter
      Sync.synchronize do
        state = @cache_states[adapter] ||= {namespace: SecureRandom.hex(16), versions: Hash.new(0)}
        version = state[:versions][name]
        state[:versions][name] = version + 1 if advance
        "#{CACHE_KEY_PREFIX}#{state[:namespace]}/#{version}/#{name}"
      end
    end
    private_class_method :cache_key
  end
end
