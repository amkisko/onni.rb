# frozen_string_literal: true

module Onni
  module Mutations
    def ready!(name)
      mutate(name, :ready) { |gates, _| power(gates) }
    end

    def park!(name)
      mutate(name, :park) { |gates, _| set_gate(gates, "powered", "false") }
    end

    def clear!(name)
      mutate(name, :clear) { |gates, _| gates.clear }
    end

    def filters!(name, **filters)
      changes = filters.transform_keys(&:to_s)
      Registry.validate_filters!(changes)
      mutate(name, :filters) do |gates, _|
        write_filters(gates, changes)
      end
    end

    def stats!(name, **settings)
      changes = settings.transform_keys(&:to_s)
      Stats::Policy.validate!(changes, nullable: true)
      mutate(name, :stats) do |gates, _|
        current = GateSnapshot.wrap(gates).stats || {"enabled" => false}
        set_gate(gates, "stats", JSON.generate(current.merge(changes).compact))
      end
    end

    def visible_group!(name, group)
      audience_mutation(name, "groups", group.to_s, visible: true)
    end

    def drop_group!(name, group)
      audience_mutation(name, "groups", group.to_s, visible: false)
    end

    def visible_actor!(name, actor)
      audience_mutation(name, "actors", Actor.id(actor), visible: true)
    end

    def drop_actor!(name, actor)
      audience_mutation(name, "actors", Actor.id(actor), visible: false)
    end

    def level!(name, value)
      level = Integer(value).clamp(0, 100)
      mutate(name, :level, level: level) do |gates, _|
        set_gate(gates, "percentage_of_actors", level.to_s)
        write_filters(gates, "level" => level)
        power(gates)
      end
    end

    def variants!(name, variants)
      Registry.validate_variants!(variants)
      mutate(name, :variants, type: "experiment") do |gates, _|
        set_gate(gates, "variants", JSON.generate(variants.transform_keys(&:to_s)))
      end
    end

    private

    def audience_mutation(name, key, value, visible:)
      raise ArgumentError, "Audience must not be empty" if value.nil? || value.empty?

      operation = :"#{visible ? "visible" : "drop"}_#{(key == "groups") ? "group" : "actor"}"
      fields = (key == "groups") ? {group_name: value} : {actor_id: value}
      mutate(name, operation, **fields) do |gates, definition|
        set_audience(gates, definition, key, value, visible: visible)
      end
    end

    def set_audience(gates, definition, key, value, visible:)
      list = Settings.list(key, definition, gates).dup
      visible ? list.push(value).uniq! : list.delete(value)
      gates.reject! { |gate| gate["key"] == key }
      set_gate(gates, "#{key}_override", JSON.generate(list))
      write_filters(gates, key => list)
      power(gates) if visible
    end

    def write_filters(gates, changes)
      filters = GateSnapshot.wrap(gates).filters.merge(changes)
      set_gate(gates, "audience_filters", JSON.generate(filters))
    end

    def mutate(name, operation, type: nil, **fields)
      definition = Registry.require_definition!(name) || Registry.definition(name) || {}
      if type && Settings.type(definition) != type
        raise ArgumentError, "Feature #{name} requires type #{type} for #{operation}"
      end

      feature_operation(name, operation, **fields) do
        adapter.add(name)
        adapter.update_gates(name) do |gates|
          power(gates) if Settings.powered?(gates, definition)
          yield(gates, definition)
        end
      end
    end

    def power(gates)
      set_gate(gates, "powered", "true")
    end

    def set_gate(gates, key, value)
      gates.reject! { |gate| gate["key"] == key }
      gates << {"key" => key, "value" => value}
    end
  end
end
