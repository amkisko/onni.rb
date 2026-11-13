# frozen_string_literal: true

require "time"
require "json"
require "objspace"
require "securerandom"

module Onni
  module Store
    CACHE_KEY_PREFIX = "onni/gates/v2/"

    @cache_states = ObjectSpace::WeakKeyMap.new

    module_function

    def visible?(name, actor = nil, record_stats: true)
      definition = Registry.definition(name)
      return false unless definition

      gates = cached_gates(name)
      return false unless Settings.powered?(gates, definition)
      result = matches?(name, actor, definition, gates)
      Stats.record(name, shown: result) if record_stats
      result
    end

    def power_state(name)
      definition = Registry.definition(name)
      return unless definition

      Settings.power_state(cached_gates(name), definition)
    end

    def variant(name, actor = nil, record_stats: true)
      definition = Registry.definition(name)
      return unless definition
      return if actor.nil?

      gates = cached_gates(name)
      return unless Settings.powered?(gates, definition)
      return unless Settings.type(definition) == "experiment"

      weights = Settings.variants(definition, gates)
      matched = weights.values.sum.positive? && !expired?(definition) &&
        Conditions.met?(name, actor, definition: definition)
      Stats.record(name, shown: matched) if record_stats
      Actor.variant_for(actor, name, weights) if matched
    end

    def matches?(name, actor, definition, gates)
      return false if expired?(definition)
      return false unless audience_matches?(name, actor, definition, gates)

      Conditions.met?(name, actor, definition: definition)
    end
    private_class_method :matches?

    def audience_matches?(name, actor, definition, gates)
      case Settings.type(definition)
      when "boolean" then true
      when "experiment" then Settings.variants(definition, gates).values.sum.positive?
      when "actors" then Settings.list("actors", definition, gates).include?(Actor.id(actor))
      when "group"
        !actor.nil? && Settings.list("groups", definition, gates).any? { |group| Group.member?(group, actor) }
      when "percentage"
        !actor.nil? && Actor.percentage_value(actor, name) < Settings.level(definition, gates)
      else false
      end
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
      return preloaded[key] if preloaded&.key?(key)

      cache = Onni.configuration.cache
      return read_gates(key) unless cache

      cache.fetch(cache_key(key), expires_in: Onni.configuration.cache_ttl) do
        read_gates(key)
      end
    end
    private_class_method :cached_gates

    def read_gates(name)
      adapter = Onni.adapter
      return adapter.gates_snapshot_for(name) if adapter.respond_to?(:gates_snapshot_for)

      adapter.gates_for(name)
    end
    private_class_method :read_gates

    def bust_cache!(name)
      key = name.to_s
      cache = Onni.configuration.cache
      if cache
        old_key = cache_key(key, advance: true)
        begin
          cache.delete(old_key)
        rescue => error
          Rails.logger.warn("Onni cache cleanup failed: #{error.class}") if defined?(Rails)
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
