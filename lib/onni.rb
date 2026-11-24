# frozen_string_literal: true

require "zlib"
require "json"
require "onni/version"
require "onni/configuration"
require "onni/stats/policy"
require "onni/sync"
require "onni/instrumenter"
require "onni/signal_policy"
require "onni/registry"
require "onni/expirations"
require "onni/actor"
require "onni/group"
require "onni/conditions"
require "onni/gate_snapshot"
require "onni/audience"
require "onni/stats"
require "onni/settings"
require "onni/flag"
require "onni/mutations"
require "onni/signals"
require "onni/request_store"
require "onni/store"
require "onni/adapters"
require "onni/delivery"
require "onni/catalogue_export"
require "onni/delivery/api"
require "onni/operations"

module Onni
  module Migrator
    autoload :Snapshot, "onni/migrator/snapshot"
    autoload :Importer, "onni/migrator/importer"
    autoload :ActiveRecordTables, "onni/migrator/active_record_tables"
  end
  extend Mutations
  extend Signals
  extend Delivery::API
  extend Operations

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      selected_adapter = configuration.adapter
      yield configuration
      @adapter = nil if selected_adapter != configuration.adapter
    end

    def adapter
      @adapter ||= build_adapter
    end

    attr_writer :adapter

    def reset_adapter!
      @adapter = nil
    end

    def visible?(name, actor = nil, record_stats: nil)
      Store.visible?(name, actor, record_stats: record_stats)
    end

    def verify_expirations!(**options)
      Expirations.verify!(**options)
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

    def variant(name, actor = nil, record_stats: nil)
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

    def define!(name, description:, expires_at:, **settings)
      Registry.define!(name, description: description, expires_at: expires_at, **settings)
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

    def register_adapter(name, &factory)
      Adapters.register(name, &factory)
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
      loaded = Store.gates_for_many(keys)
      loaded.transform_values! { |gates| GateSnapshot.wrap(gates) }
      Store.store_preloaded!(loaded)
      loaded.size
    end

    def flush_stats!
      Stats::Buffer.flush!
    end

    def reset_request!
      Stats::Buffer.flush!
    rescue => error
      Instrumenter.warn("Onni stats flush failed: #{error.class}")
    ensure
      RequestStore.clear!
    end

    private

    def build_adapter
      Adapters.build(configuration.adapter)
    end
  end
end
