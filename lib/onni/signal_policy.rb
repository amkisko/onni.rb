# frozen_string_literal: true

module Onni
  module SignalPolicy
    LIMIT = 32
    MAXIMUM = (2**63) - 1
    MINIMUM = -(2**63)

    module_function

    def validate!(policies)
      unless policies.is_a?(Hash) && (policies.keys.map(&:to_s) | ["exception"]).size <= LIMIT
        raise ArgumentError, "Signals require a mapping of at most #{LIMIT} keys including exception"
      end
      policies.each do |key, policy|
        validate_name!(key)
        validate_threshold!(policy)
      end
    end

    def validate_name!(key)
      valid_name = (key.is_a?(String) || key.is_a?(Symbol)) && key.to_s.match?(/\A[a-z][a-z0-9_]{0,63}\z/)
      unless valid_name
        raise ArgumentError, "Signal keys require lowercase names up to 64 characters"
      end
    end

    def validate_threshold!(policy)
      unless policy.is_a?(Hash) && (policy.keys - ["threshold"]).empty?
        raise ArgumentError, "Signal policy accepts threshold only"
      end
      value = policy["threshold"]
      return if value.nil? || (value.is_a?(Integer) && value.between?(1, MAXIMUM))

      raise ArgumentError, "Signal threshold must be a positive 64-bit integer or nil"
    end

    def validate_capacity!(levels, signal)
      return if levels.key?(signal.to_s)
      return if (levels.keys | ["exception", signal.to_s]).size <= LIMIT

      raise ArgumentError, "Reset signals before adding more retained levels"
    end

    def integer!(value)
      return value if value.is_a?(Integer) && value.between?(MINIMUM, MAXIMUM)

      raise ArgumentError, "Signal delta and level must be signed 64-bit integers"
    end

    def read(gates, key)
      gate = gates.find { |entry| entry["key"] == key }
      gate ? JSON.parse(gate["value"]) : {}
    end

    def settings(definition, gates)
      defaults = definition.fetch("signals", {})
      overrides = read(gates, "signals")
      overrides.empty? ? defaults : defaults.merge(overrides)
    end

    def require_key!(definition, gates, key)
      validate_name!(key)
      policies = settings(definition, gates)
      unless key.to_s == "exception" || policies.key?(key.to_s)
        raise ArgumentError, "Signal #{key} is not declared"
      end
      policies
    end
  end
end
