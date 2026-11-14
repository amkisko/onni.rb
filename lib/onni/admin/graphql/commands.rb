# frozen_string_literal: true

module Onni
  module Admin
    module GraphQL
      module Commands
        module_function

        IMPLEMENTATIONS = {
          ready: ->(name) { Onni.ready!(name) },
          park: ->(name, reason: nil) { Onni.park!(name, reason: reason) },
          clear: ->(name) { Onni.clear!(name) },
          observe: ->(name, signal:, delta: 1) { Onni.observe!(name, signal, delta) },
          reset_signals: ->(name, signal: nil) { Onni.reset_signals!(name, signal) },
          set_filters: ->(name, filters:) { Onni.filters!(name, **filters.to_h) },
          set_stats: ->(name, stats:) { Onni.stats!(name, **stats.to_h) },
          set_experiment_filters: lambda { |name, experiment:, filters:|
            Onni.experiment_filters!(name, experiment, **filters.to_h)
          },
          set_signal_threshold: lambda { |name, signal:, threshold:|
            Onni.signals!(name, **{signal => {threshold: threshold}})
          },
          set_variants: ->(name, variants:) { Onni.variants!(name, weights(variants)) }
        }.freeze

        def call(operation, name, arguments)
          IMPLEMENTATIONS.fetch(operation).call(name, **arguments)
          Snapshot.find(name)
        rescue KeyError
          raise ::GraphQL::ExecutionError.new("Feature or setting not found", extensions: {code: "NOT_FOUND"})
        rescue ArgumentError, TypeError => error
          raise ::GraphQL::ExecutionError.new(error.message, extensions: {code: "INVALID_INPUT"})
        end

        def weights(entries)
          weights = entries.to_h { |entry| [entry[:name], entry[:weight]] }
          raise ArgumentError, "Duplicate variant names" unless weights.size == entries.size

          weights
        end
      end
    end
  end
end
