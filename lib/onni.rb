# frozen_string_literal: true

require "zlib"
require "json"
require "onni/version"
require "onni/configuration"
require "onni/sync"
require "onni/instrumenter"
require "onni/registry"
require "onni/actor"
require "onni/group"
require "onni/conditions"
require "onni/stats"
require "onni/settings"
require "onni/flag"
require "onni/mutations"
require "onni/request_store"
require "onni/store"
require "onni/adapters/memory"
require "onni/adapters/active_record"
require "onni/migrator/snapshot"
require "onni/migrator/importer"
require "onni/engine" if defined?(Rails::Engine)

module Onni
  extend Mutations

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
      Sync.reset!
      @adapter = nil
    end

    def adapter
      @adapter ||= build_adapter
    end

    attr_writer :adapter

    def reset_adapter!
      @adapter = nil
    end

    def visible?(name, actor = nil, record_stats: true)
      Store.visible?(name, actor, record_stats: record_stats)
    end

    def ready?(name)
      Store.power_state(name) == :ready
    end

    def pending?(name)
      Store.power_state(name) == :pending
    end

    def parked?(name)
      Store.power_state(name) == :parked
    end

    def variant(name, actor = nil, record_stats: true)
      Store.variant(name, actor, record_stats: record_stats)
    end

    def variants(name)
      self[name].variants
    end

    def level(name)
      self[name].level
    end

    def add(name)
      Registry.require_definition!(name)
      adapter.add(name)
    end

    def exist?(name)
      adapter.exist?(name)
    end

    def features
      adapter.feature_keys.map { |key| Flag.new(key) }
    end

    def [](name)
      Flag.new(name)
    end

    def register_group(name, &block)
      Group.register(name, &block)
    end

    # Import from any prior feature-flag store via a source with #feature_keys and #gates.
    def migrate!(source)
      Migrator::Importer.new(source).call
    end

    def sync_registry!
      Registry.config.each_key { |key| add(key) unless exist?(key) }
    end

    def purge_stats!(**kwargs)
      Stats.purge!(**kwargs)
    end

    def stats_overview
      Stats.overview
    end

    # Preload gates into the fiber-local request store (one adapter round-trip).
    # Pass names, or omit to load every YAML registry key.
    def preload!(*names)
      keys = names.flatten.map!(&:to_s)
      keys = Registry.config.keys.map(&:to_s) if keys.empty?
      loaded =
        if adapter.respond_to?(:gates_for_many)
          adapter.gates_for_many(keys)
        else
          keys.each_with_object({}) { |key, hash| hash[key] = adapter.gates_for(key) }
        end
      RequestStore.gates = (RequestStore.gates || {}).merge(loaded)
      loaded.size
    end

    def flush_stats!
      Stats::Buffer.flush!
    end

    def reset_request!
      Stats::Buffer.flush! if configuration.stats_buffer
    rescue => error
      Rails.logger.warn("Onni stats flush failed: #{error.class}") if defined?(Rails)
    ensure
      RequestStore.clear!
    end

    private

    def feature_operation(name, operation, **fields)
      Instrumenter.instrument("feature_operation", feature_name: name.to_s, operation: operation, **fields) do |payload|
        Registry.require_definition!(name)
        yield(payload)
        Store.bust_cache!(name)
        payload[:result] = true
        true
      end
    end

    def build_adapter
      case configuration.adapter
      when :memory then Adapters::Memory.new
      when :active_record then Adapters::ActiveRecord.new
      else
        raise ArgumentError, "Unknown Onni adapter #{configuration.adapter.inspect}"
      end
    end
  end
end
