# frozen_string_literal: true

module Onni
  module Registry
    module Validation
      TYPES = %w[boolean percentage group actors experiment].freeze

      def validate_definition!(name, definition)
        raise ArgumentError, "Feature #{name} must be a mapping" unless definition.is_a?(Hash)

        type = definition.fetch("type", "group")
        raise ArgumentError, "Unknown feature type #{type.inspect} for #{name}" unless TYPES.include?(type)

        definition["type"] = type
        validate_level!(definition["level"]) if definition.key?("level")
        validate_lists!(name, definition)
        validate_variants!(definition["variants"]) if definition.key?("variants")
      end

      def validate_variants!(variants)
        valid = variants.is_a?(Hash) && variants.all? { |key, weight| valid_weight?(key, weight) }
        valid &&= variants.empty? || variants.values.sum.positive?
        raise ArgumentError, "Variants require named nonnegative integer weights and a positive total" unless valid
      end

      private

      def validate_lists!(name, definition)
        %w[groups actors conditions].each do |key|
          validate_strings!(name, key, definition[key]) if definition.key?(key)
        end
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
