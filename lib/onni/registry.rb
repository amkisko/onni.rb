# frozen_string_literal: true

require "time"
require "yaml"
require "onni/registry/validation"

module Onni
  module Registry
    extend Validation

    module_function

    def config
      loaded = @config
      return loaded if loaded

      Sync.synchronize do
        @config ||= load_config
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
      message = "Feature `#{name}` not found in features.yml"
      if defined?(Rails)
        Rails.logger.error(message)
        ActionReporter.notify(message) if defined?(ActionReporter) && Rails.env.production?
      end
      raise KeyError, message
    end

    def load_config
      path = Onni.configuration.features_path
      path ||= default_features_path
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

    def default_features_path
      return unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      Rails.root.join("config/features.yml")
    end
    private_class_method :default_features_path
  end
end
