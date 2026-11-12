# frozen_string_literal: true

module Onni
  module Migrator
    # Copies gates from any source that exposes #feature_keys and #gates.
    # Gate rows: feature_key, key, value (String or Symbol keys).
    # Imports: boolean, actors, groups, percentage_of_actors, variants.
    # Skips unknown registry keys and unsupported gate keys (counted in skipped_gates).
    class Importer
      SUPPORTED_GATE_KEYS = %w[boolean actors groups percentage_of_actors variants].freeze

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

          unless SUPPORTED_GATE_KEYS.include?(gate_key)
            skipped_gates += 1
            next
          end

          Onni.add(feature_key)
          Onni.adapter.add_gate(feature_key, gate_key, value)
          Onni::Store.bust_cache!(feature_key)
          gates += 1
        end

        {features: features, gates: gates, skipped_gates: skipped_gates}
      end

      private

      def gate_field(row, name)
        row[name] || row[name.to_s]
      end
    end
  end
end
