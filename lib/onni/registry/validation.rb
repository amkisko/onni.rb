# frozen_string_literal: true

module Onni
  module Registry
    module Validation
      FILTER_KEYS = %w[everyone groups actors excluded_groups excluded_actors level].freeze

      def validate_definition!(name, definition)
        raise ArgumentError, "Feature #{name} must be a mapping" unless definition.is_a?(Hash)

        if definition.key?("type") && definition["type"] != "experiment"
          raise ArgumentError, "Feature #{name} uses audience filters; only type: experiment is supported"
        end

        validate_defaults!(name, definition)
      end

      def validate_filters!(filters, nullable: true)
        unless filters.is_a?(Hash) && (filters.keys - FILTER_KEYS).empty?
          raise ArgumentError, "Unknown audience filter"
        end

        filters.each do |key, value|
          next if value.nil? && nullable

          case key
          when "everyone"
            raise ArgumentError, "Everyone must be true or false" unless value == true || value == false
          when "level" then validate_level!(value)
          else validate_strings!("audience", key, value)
          end
        end
      end

      def validate_variants!(variants)
        valid = variants.is_a?(Hash) && variants.all? { |key, weight| valid_weight?(key, weight) }
        valid &&= variants.empty? || variants.values.sum.positive?
        raise ArgumentError, "Variants require named nonnegative integer weights and a positive total" unless valid
      end

      private

      def validate_defaults!(name, definition)
        validate_filters!(definition.slice(*FILTER_KEYS), nullable: false)
        validate_strings!(name, "conditions", definition["conditions"]) if definition.key?("conditions")
        validate_variants!(definition["variants"]) if definition.key?("variants")
        Stats::Policy.validate!(definition["stats"]) if definition.key?("stats")
      end

      def valid_weight?(key, weight)
        (key.is_a?(String) || key.is_a?(Symbol)) && !key.to_s.empty? &&
          weight.is_a?(Integer) && weight >= 0
      end

      def validate_strings!(name, key, values)
        return if values.is_a?(Array) && values.all? { |value| value.is_a?(String) && !value.empty? }

        raise ArgumentError, "Feature #{name} #{key} must be an array of nonempty strings"
      end

      def validate_level!(level)
        return if level.is_a?(Integer) && level.between?(0, 100)

        raise ArgumentError, "Percentage level must be an integer in 0..100"
      end
    end
  end
end
