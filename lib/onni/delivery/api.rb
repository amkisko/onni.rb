# frozen_string_literal: true

module Onni
  class Delivery
    module API
      def export_catalogue(**options)
        CatalogueExport.call(**options)
      end

      def deliver(name, actor = nil, parked:, &block)
        Delivery.inline(name, actor, parked: parked, &block)
      end

      def selected(name, actor = nil)
        Delivery.selected(name, actor)
      end

      def experiment_filters!(name, experiment, **filters)
        key = experiment.to_s
        raise ArgumentError, "Unknown Delivery experiment" unless Delivery.fetch(name).experiments.key?(key)

        changes = filters.transform_keys(&:to_s)
        Registry.validate_filters!(changes)
        mutate(name, :experiment_filters, experiment: key) do |gates, _|
          current = SignalPolicy.read(gates, "delivery_experiments")
          current[key] = current.fetch(key, {}).merge(changes)
          set_gate(gates, "delivery_experiments", JSON.generate(current))
        end
      end
    end
  end
end
