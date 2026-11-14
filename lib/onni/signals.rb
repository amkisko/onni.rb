# frozen_string_literal: true

module Onni
  module Signals
    def observe!(name, signal, delta = 1)
      SignalPolicy.integer!(delta)
      parked = false
      level = nil
      mutate(name, :observe, signal: signal.to_s, delta: delta) do |gates, definition|
        policies = SignalPolicy.require_key!(definition, gates, signal)
        level = observe_level!(gates, signal, delta)
        parked = park_at_threshold!(gates, definition, policies.dig(signal.to_s, "threshold"), level)
      end
      if parked
        emit_operation(feature_name: name.to_s,
          operation: :park, reason: "signal:#{signal}", result: true)
      end
      level
    end

    private def observe_level!(gates, signal, delta)
      levels = SignalPolicy.read(gates, "signal_levels")
      level = SignalPolicy.integer!(levels.fetch(signal.to_s, 0) + delta)
      SignalPolicy.validate_capacity!(levels, signal)
      levels[signal.to_s] = level
      set_gate(gates, "signal_levels", JSON.generate(levels))
      level
    end

    private def park_at_threshold!(gates, definition, threshold, level)
      return false unless threshold && level >= threshold && Settings.powered?(gates, definition)

      set_gate(gates, "powered", "false")
      true
    end

    def signals!(name, **policies)
      changes = Registry.copy_definition(policies)
      SignalPolicy.validate!(changes)
      mutate(name, :signals) do |gates, definition|
        effective = SignalPolicy.settings(definition, gates).merge(changes)
        SignalPolicy.validate!(effective)
        overrides = SignalPolicy.read(gates, "signals").merge(changes)
        set_gate(gates, "signals", JSON.generate(overrides))
      end
    end

    def signal_level(name, signal)
      definition = Registry.require_definition!(name)
      gates = adapter.gates_for(name)
      SignalPolicy.require_key!(definition, gates, signal)
      SignalPolicy.read(gates, "signal_levels").fetch(signal.to_s, 0)
    end

    def reset_signals!(name, signal = nil)
      mutate(name, :reset_signals) do |gates, definition|
        if signal.nil?
          gates.reject! { |gate| gate["key"] == "signal_levels" }
        else
          SignalPolicy.require_key!(definition, gates, signal)
          levels = SignalPolicy.read(gates, "signal_levels")
          levels.delete(signal.to_s)
          set_gate(gates, "signal_levels", JSON.generate(levels))
        end
      end
    end
  end
end
