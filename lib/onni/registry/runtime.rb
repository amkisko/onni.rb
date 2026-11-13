# frozen_string_literal: true

module Onni
  module Registry
    module Runtime
      SETTINGS = (Validation::FILTER_KEYS + %w[type variants conditions stats]).freeze

      def define!(name, description:, expires_at:, **settings)
        key = runtime_name(name)
        definition = runtime_definition(key, description, expires_at, settings)
        Sync.synchronize do
          @config ||= load_registry
          runtime = @runtime_definitions || {}
          if @config.key?(key) && !runtime.key?(key)
            raise ArgumentError, "Feature #{key} is defined in features.yml"
          end

          @runtime_definitions = runtime.merge(key => definition)
          @config = @config.merge(key => definition)
        end
        true
      end

      private

      def runtime_name(name)
        valid_type = name.is_a?(String) || name.is_a?(Symbol)
        unless valid_type && name.to_s.strip.length.positive?
          raise ArgumentError, "Feature name must not be blank"
        end

        name.to_s.dup.freeze
      end

      def runtime_definition(name, description, expires_at, settings)
        validate_metadata!(description, expires_at)
        raise ArgumentError, "Unknown feature settings" unless (settings.keys.map(&:to_s) - SETTINGS).empty?

        deadline = Time.parse(expires_at).utc
        definition = copy_definition(settings.merge(description: description, expires_at: expires_at,
          expires_at_time: deadline))
        validate_definition!(name, definition)
        definition
      end

      def validate_metadata!(description, expires_at)
        unless description.is_a?(String) && !description.strip.empty?
          raise ArgumentError, "Feature description must not be blank"
        end
        unless expires_at.is_a?(String) && !expires_at.strip.empty?
          raise ArgumentError, "Feature expiration must be a timestamp string"
        end
      end

      def copy_definition(value, depth = 0)
        raise ArgumentError, "Feature settings must be scalars, flat lists, or flat mappings" if depth > 2

        case value
        when Hash then copy_mapping(value, depth)
        when Array then value.map { |entry| copy_definition(entry, depth + 1) }.freeze
        when String, Time then value.dup.freeze
        when Symbol, Integer, Float, TrueClass, FalseClass, NilClass then value
        else raise ArgumentError, "Unsupported feature setting value"
        end
      end

      def copy_mapping(mapping, depth)
        copied = mapping.to_h do |key, value|
          raise ArgumentError, "Feature setting keys must be names" unless key.is_a?(String) || key.is_a?(Symbol)

          [key.to_s.dup.freeze, copy_definition(value, depth + 1)]
        end
        raise ArgumentError, "Duplicate feature setting keys" unless copied.size == mapping.size

        copied.freeze
      end
    end
  end
end
