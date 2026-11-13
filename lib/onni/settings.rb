# frozen_string_literal: true

module Onni
  module Settings
    LEGACY_AUDIENCE_KEYS = {"actors" => "actors", "group" => "groups", "percentage" => "percentage_of_actors"}.freeze

    module_function

    def type(definition)
      definition.fetch("type", "group")
    end

    def powered?(gates, definition = {})
      return false if gates.empty?

      power = gates.find { |gate| gate["key"] == "powered" }
      return power["value"] == "true" if power

      legacy_powered?(gates, definition)
    end

    def power_state(gates, definition)
      return :ready if powered?(gates, definition)

      parked = gates.any? { |gate| %w[powered boolean].include?(gate["key"]) && gate["value"] == "false" }
      parked ? :parked : :pending
    end

    def legacy_powered?(gates, definition)
      audience_key = LEGACY_AUDIENCE_KEYS[type(definition)]
      gates.any? do |gate|
        (gate["key"] == "boolean" && gate["value"] == "true") ||
          (audience_key && gate["key"] == audience_key)
      end
    end
    private_class_method :legacy_powered?

    def list(key, definition, gates)
      override_key = "#{key}_override"
      override = gates.find { |gate| gate["key"] == override_key }
      return list_override(override) if override

      legacy = gates.select { |gate| gate["key"] == key }.map { |gate| gate["value"] }
      legacy.empty? ? definition.fetch(key, []) : legacy
    end

    def list_override(gate)
      values = JSON.parse(gate["value"])
      (values.is_a?(Array) && values.all? { |value| value.is_a?(String) }) ? values : []
    rescue JSON::ParserError
      []
    end
    private_class_method :list_override

    def level(definition, gates)
      gate = gates.find { |entry| entry["key"] == "percentage_of_actors" }
      gate ? gate["value"].to_i.clamp(0, 100) : definition.fetch("level", 0)
    end

    def variants(definition, gates)
      gate = gates.find { |entry| entry["key"] == "variants" }
      raw = gate ? JSON.parse(gate["value"]) : definition.fetch("variants", {})
      return {} unless raw.is_a?(Hash)

      gate ? raw.transform_values!(&:to_i) : raw.transform_keys(&:to_s).transform_values(&:to_i)
    rescue JSON::ParserError
      {}
    end
  end
end
