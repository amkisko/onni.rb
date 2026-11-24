# frozen_string_literal: true

module Onni
  module Admin
    module GraphQL
      module Snapshot
        module_function

        def find(name)
          definition = Registry.definition(name)
          build(name, definition, Onni.adapter.gates_for(name)) if definition
        end

        def page(first:, after: nil)
          raise ::GraphQL::ExecutionError, "First must be in 1..100" unless first.between?(1, 100)

          definitions = Registry.config
          keys = definitions.keys.sort
          names, more = page_keys(keys, first, after)
          gates = Store.gates_for_many(names)
          {items: names.map { |name| build(name, definitions.fetch(name), gates.fetch(name)) },
           next_cursor: more ? names.last : nil, total_count: keys.length}
        end

        def page_keys(keys, first, after)
          start = after ? (keys.bsearch_index { |key| key > after } || keys.length) : 0
          names = keys.slice(start, first + 1) || []
          [names.first(first), names.length > first]
        end

        def build(name, definition, gates)
          owner = Sync.synchronize { Delivery.entries[name.to_s] }
          {name: name.to_s, type: definition["type"], conditions: definition.fetch("conditions", []),
           raise_on_expiration: definition["raise_on_expiration"] == true, description: definition["description"], expires_at: definition["expires_at"],
           expiration_status: Expirations.status(definition).to_s, power: Settings.power_state(gates, definition),
           **settings(name, owner, definition, gates)}
        end

        def settings(name, owner, definition, gates)
          {filters: Settings.filters(definition, gates),
           variants: Settings.variants(definition, gates).map { |key, weight| {name: key, weight: weight} },
           signals: signals(definition, gates), stats: Stats::Policy.settings(definition, gates),
           experiments: owner ? Delivery.filters(name, owner, gates).map { |key, filters| {name: key, filters: filters} } : []}
        end

        def signals(definition, gates)
          policies = SignalPolicy.settings(definition, gates)
          levels = SignalPolicy.read(gates, "signal_levels")
          (policies.keys | levels.keys | ["exception"]).sort.map do |key|
            {key: key, level: levels.fetch(key, 0), threshold: policies.dig(key, "threshold")}
          end
        end
      end
    end
  end
end
