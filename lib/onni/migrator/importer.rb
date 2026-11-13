# frozen_string_literal: true

module Onni
  module Migrator
    # Copies gates from any source that exposes #feature_keys and #gates.
    # Gate rows: feature_key, key, value (String or Symbol keys).
    # Imports: boolean, actors, groups, percentage_of_actors, variants.
    # Skips unknown registry keys and unsupported gate keys (counted in skipped_gates).
    class Importer
      SETTINGS_GATES = %w[boolean powered actors actors_override groups groups_override
        percentage_of_actors audience_filters stats].freeze

      def initialize(source)
        @source = source
      end

      def call
        features = 0
        gates = 0
        skipped_gates = 0

        @source.feature_keys.each do |key|
          next unless Registry.known?(key)

          Onni.add(key)
          features += 1
        end

        @source.gates.each do |row|
          feature_key = gate_field(row, :feature_key)
          gate_key = gate_field(row, :key).to_s
          value = gate_field(row, :value)
          next unless Registry.known?(feature_key)

          unless supported?(feature_key, gate_key) && valid_gate?(gate_key, value)
            skipped_gates += 1
            next
          end

          Onni.add(feature_key)
          write_gate(feature_key, gate_key, value)
          Onni::Store.bust_cache!(feature_key)
          gates += 1
        end

        {features: features, gates: gates, skipped_gates: skipped_gates}
      end

      private

      def supported?(feature_key, gate_key)
        type = Settings.type(Registry.definition(feature_key) || {})
        SETTINGS_GATES.include?(gate_key) || (type == "experiment" && gate_key == "variants")
      end

      def write_gate(feature_key, gate_key, value)
        gate_key = "powered" if gate_key == "boolean"
        value = Integer(value).to_s if gate_key == "percentage_of_actors"
        Onni.adapter.update_gates(feature_key) do |entries|
          entries.reject! { |gate| gate["key"] == gate_key } unless %w[actors groups].include?(gate_key)
          entry = {"key" => gate_key, "value" => value.to_s}
          entries << entry unless entries.include?(entry)
        end
      end

      def valid_gate?(key, value)
        case key
        when "boolean", "powered" then %w[true false].include?(value.to_s)
        when "percentage_of_actors" then Integer(value).between?(0, 100)
        when "variants", "audience_filters", "stats" then valid_settings?(key, value)
        when "actors_override", "groups_override"
          values = JSON.parse(value)
          values.is_a?(Array) && values.all? { |entry| entry.is_a?(String) && !entry.empty? }
        else !value.to_s.empty?
        end
      rescue ArgumentError, TypeError, JSON::ParserError
        false
      end

      def valid_settings?(key, value)
        settings = JSON.parse(value)
        case key
        when "variants" then Registry.validate_variants!(settings)
        when "audience_filters" then Registry.validate_filters!(settings)
        when "stats" then Stats::Policy.validate!(settings)
        end
        true
      end

      def gate_field(row, name)
        value = row[name]
        value.nil? ? row[name.to_s] : value
      end
    end
  end
end
