# frozen_string_literal: true

module Onni
  class Delivery
    module Executor
      module_function

      def run(name, path, policy, parked:, experiment:)
        return parked.call if path == :parked

        begin
          return experiment.call
        rescue => error
          raise if defined?(::ActiveRecord::Rollback) && error.is_a?(::ActiveRecord::Rollback)
        end
        Instrumenter.instrument("delivery_error", feature_name: name.to_s,
          experiment: path, error_class: error.class.name)
        if policy.fetch(:count_programming_errors) || !error.is_a?(NameError)
          Onni.observe!(name, policy.fetch(:signal))
        end
        parked.call
      end
    end
  end
end
