# frozen_string_literal: true

module Onni
  module Stats
    module Policy
      EMPTY = {}.freeze
      DEFAULTS = {"enabled" => true}.freeze
      KEYS = %w[enabled sample_rate].freeze

      module_function

      def validate!(settings, nullable: false)
        unless settings.is_a?(Hash) && (settings.keys - KEYS).empty?
          raise ArgumentError, "Stats settings accept enabled and sample_rate"
        end

        settings.each do |key, value|
          next if value.nil? && nullable

          valid = (key == "enabled") ? boolean?(value) : rate?(value)
          raise ArgumentError, "Invalid stats #{key}" unless valid
        end
      end

      def validate_option!(value)
        raise ArgumentError, "record_stats must be true, false, or nil" unless value.nil? || boolean?(value)
      end

      def parse(gates)
        gate = gates.find { |entry| entry["key"] == "stats" }
        return EMPTY unless gate

        settings = JSON.parse(gate["value"])
        validate!(settings)
        settings.freeze
      rescue ArgumentError, JSON::ParserError
        nil
      end

      def effective(definition, gates)
        runtime = gates ? GateSnapshot.wrap(gates).stats : EMPTY
        return unless runtime

        defaults = definition.fetch("stats", DEFAULTS)
        runtime.empty? ? defaults : defaults.merge(runtime)
      end

      def enabled?(policy, option)
        return false unless policy

        option == true || (option.nil? && policy.fetch("enabled", true))
      end

      def settings(definition, gates)
        policy = effective(definition, gates)
        return {"enabled" => false, "sample_rate" => 0.0} unless policy

        config = Onni.configuration
        {"enabled" => config.stats_enabled && policy.fetch("enabled", true),
         "sample_rate" => policy.fetch("sample_rate", config.stats_sample_rate)}
      end

      def boolean?(value)
        value == true || value == false
      end
      private_class_method :boolean?

      def rate?(value)
        (value.is_a?(Integer) || value.is_a?(Float)) && value.finite? && value.between?(0, 1)
      end
      private_class_method :rate?
    end
  end
end
