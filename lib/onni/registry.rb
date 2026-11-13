# frozen_string_literal: true

require "time"
require "yaml"
require "onni/registry/validation"
require "onni/registry/runtime"

module Onni
  module Registry
    extend Validation
    extend Runtime

    module_function

    def config
      loaded = @config
      return loaded if loaded

      Sync.synchronize do
        @config ||= load_registry
      end
    end

    def reload!
      Sync.synchronize do
        @config = nil
      end
      config
    end

    def known?(name)
      config.key?(name.to_s)
    end

    def definition(name)
      config[name.to_s]
    end

    def require_definition!(name)
      definition(name) || raise_unknown!(name)
    end

    def raise_unknown!(name)
      message = "Feature `#{name}` is not defined"
      Onni.configuration.logger&.error(message)
      raise KeyError, message
    end

    def load_registry
      declared = load_config
      runtime = @runtime_definitions || {}
      collisions = declared.keys & runtime.keys
      raise ArgumentError, "YAML and runtime definitions collide: #{collisions.join(", ")}" unless collisions.empty?

      declared.merge(runtime)
    end
    private_class_method :load_registry

    def load_config
      path = Onni.configuration.features_path
      return {} if path.nil? || !File.exist?(path)

      raw = File.read(path)
      loaded = YAML.safe_load(raw, aliases: true)
      return {} unless loaded.is_a?(Hash)

      loaded.each do |name, definition|
        validate_definition!(name, definition)
        attach_expiry!(definition)
      end
      loaded
    end
    private_class_method :load_config

    def attach_expiry!(definition)
      raw = definition["expires_at"]
      return if raw.nil? || raw.to_s.empty?

      definition["expires_at_time"] = Time.parse(raw.to_s).utc
    rescue ArgumentError, TypeError
      nil
    end
    private_class_method :attach_expiry!
  end
end
