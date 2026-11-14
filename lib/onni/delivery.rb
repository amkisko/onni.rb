# frozen_string_literal: true

require "onni/delivery/declarations"
require "onni/delivery/executor"

module Onni
  class Delivery
    extend Declarations

    EMPTY_TARGETING = {}.freeze

    class Inline
      def self.experiments
        {"on" => {"everyone" => true}}
      end

      def self.policy
        Declarations::DEFAULT_RESCUE_POLICY
      end

      def self.validate!
      end
    end

    class << self
      def entries
        @entries ||= {}
      end

      def check_binding!(name, owner)
        Sync.synchronize { check_binding_unlocked!(name, owner) }
      end

      def register(name, owner)
        Sync.synchronize do
          check_binding_unlocked!(name, owner)
          entries[name.to_s] = owner
        end
      end

      private def check_binding_unlocked!(name, owner)
        existing = entries[name.to_s]
        same = existing == owner || (existing&.name && existing.name == owner.name)
        raise ArgumentError, "Feature #{name} already has a Delivery binding" if existing && !same
      end

      def fetch(name)
        Sync.synchronize { entries.fetch(name.to_s) { raise ArgumentError, "Feature #{name} has no Delivery" } }
      end

      def validate_variants!(name, weights, names = nil)
        unless names
          owner = Sync.synchronize { entries[name.to_s] }
          names = owner ? owner.experiments.keys : []
        end
        unless (weights.keys.map(&:to_s) & names).empty?
          raise ArgumentError, "Variant weights and Delivery experiments must have different names"
        end
      end

      def targeting_overrides(name, gates)
        defaults = Registry.require_definition!(name).fetch("delivery_experiments", EMPTY_TARGETING)
        overrides = SignalPolicy.read(gates, "delivery_experiments")
        return defaults if overrides.empty?
        return overrides if defaults.empty?

        defaults.merge(overrides) { |_, catalogue, runtime| catalogue.merge(runtime) }
      end

      def filters(name, owner, gates)
        overrides = targeting_overrides(name, gates)
        owner.experiments.to_h { |key, defaults| [key, defaults.merge(overrides.fetch(key, {})).compact] }
      end

      def selected(name, actor = nil)
        definition = Registry.require_definition!(name)
        owner = fetch(name)
        validate_configuration!(definition, owner)
        owner.validate!
        gates = Store.send(:cached_gates, name)
        return :parked unless Settings.powered?(gates)

        choose_path(name, actor, owner, gates)
      end

      private def validate_configuration!(definition, owner)
        configured = definition["delivery_experiments"]
        return unless configured
        return if (configured.keys - owner.experiments.keys).empty?

        raise ArgumentError, "Unknown configured Delivery experiment"
      end

      private def choose_path(name, actor, owner, gates)
        overrides = targeting_overrides(name, gates)
        owner.experiments.each do |key, defaults|
          targeting = overrides.key?(key) ? defaults.merge(overrides[key]).compact : defaults
          return key.to_sym if Audience.matches?(name, actor, targeting)
        end
        :parked
      end

      def call(actor = nil, *arguments, **keywords, &block)
        path = Delivery.selected(feature_name, actor)
        instance = new
        Executor.run(feature_name, path, policy,
          parked: -> { instance.public_send(:parked, *arguments, **keywords, &block) },
          experiment: -> { instance.public_send(path, *arguments, **keywords, &block) })
      end

      def inline(name, actor, parked:, &experiment)
        unless parked.respond_to?(:call) && experiment
          raise ArgumentError, "Provide parked callable and experiment block"
        end
        Registry.require_definition!(name)
        validate_variants!(name, Settings.variants(Registry.definition(name), Onni.adapter.gates_for(name)), ["on"])
        register(name, Inline)
        path = selected(name, actor)
        Executor.run(name, path, Inline.policy, parked: parked, experiment: experiment)
      end
    end
  end
end
