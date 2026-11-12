# frozen_string_literal: true

require "time"
require "json"

module Onni
  module Store
    CACHE_KEY_PREFIX = "onni/gates/"

    module_function

    def enabled?(name, actor = nil, record_stats: true)
      return false unless Registry.known?(name)

      result = evaluate(name, actor)
      Stats.record(name, enabled: result) if record_stats
      result
    end

    def variant(name, actor, record_stats: true)
      return unless Registry.known?(name)
      return if actor.nil?

      definition = Registry.definition(name) || {}
      return if expired?(definition)

      gates = cached_gates(name)
      return if gates.empty?

      matched =
        boolean_enabled?(gates) ||
        actor_enabled?(gates, actor) ||
        group_enabled?(gates, actor) ||
        percentage_enabled?(gates, name, actor)
      return unless matched
      return unless Conditions.met?(name, actor, definition: definition)

      Stats.record(name, enabled: true) if record_stats

      variants = variant_weights(definition, gates)
      return if variants.blank?

      Actor.variant_for(actor, name, variants)
    end

    def evaluate(name, actor)
      definition = Registry.definition(name) || {}
      return false if expired?(definition)

      gates = cached_gates(name)
      return false if gates.empty?

      matched =
        boolean_enabled?(gates) ||
        actor_enabled?(gates, actor) ||
        group_enabled?(gates, actor) ||
        percentage_enabled?(gates, name, actor)
      return false unless matched

      Conditions.met?(name, actor, definition: definition)
    end
    private_class_method :evaluate

    def variant_weights(definition, gates)
      raw = definition["variants"]
      return normalize_variants(raw) if raw.present?

      gate = Array(gates).find { |entry| entry["key"] == "variants" }
      return {} unless gate

      normalize_variants(JSON.parse(gate["value"]))
    rescue JSON::ParserError
      {}
    end
    private_class_method :variant_weights

    def normalize_variants(raw)
      raw.transform_keys(&:to_s).transform_values(&:to_i)
    end
    private_class_method :normalize_variants

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
      return Onni.adapter.gates_for(key) unless cache

      cache.fetch(cache_key(key), expires_in: Onni.configuration.cache_ttl) do
        Onni.adapter.gates_for(key)
      end
    end
    private_class_method :cached_gates

    def bust_cache!(name)
      key = name.to_s
      Onni.configuration.cache&.delete(cache_key(key))
      RequestStore.gates&.delete(key)
    end

    def cache_key(name)
      "#{CACHE_KEY_PREFIX}#{Onni.adapter.object_id}/#{name}"
    end
    private_class_method :cache_key

    def boolean_enabled?(gates)
      gates.any? { |gate| gate["key"] == "boolean" && gate["value"] == "true" }
    end
    private_class_method :boolean_enabled?

    def actor_enabled?(gates, actor)
      actor_id = Actor.id(actor)
      return false if actor_id.blank?

      gates.any? { |gate| gate["key"] == "actors" && gate["value"] == actor_id }
    end
    private_class_method :actor_enabled?

    def group_enabled?(gates, actor)
      return false if actor.nil?

      gates.any? { |gate| gate["key"] == "groups" && Group.member?(gate["value"], actor) }
    end
    private_class_method :group_enabled?

    def percentage_enabled?(gates, name, actor)
      return false if actor.nil?

      gate = gates.find { |entry| entry["key"] == "percentage_of_actors" }
      return false unless gate

      Actor.percentage_value(actor, name) < gate["value"].to_i
    end
    private_class_method :percentage_enabled?
  end
end
