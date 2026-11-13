# frozen_string_literal: true

module Onni
  module Settings
    module_function

    def type(definition)
      definition["type"]
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
      gates.any? do |gate|
        (gate["key"] == "boolean" && gate["value"] == "true") ||
          %w[actors groups percentage_of_actors].include?(gate["key"])
      end
    end
    private_class_method :legacy_powered?

    def list(key, definition, gates)
      filters(definition, gates)[key] || []
    end

    def filters(definition, gates)
      overrides = GateSnapshot.wrap(gates).filters
      overrides.empty? ? definition : definition.merge(overrides)
    end

    def level(definition, gates)
      filters(definition, gates)["level"] || 0
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
