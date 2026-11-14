# frozen_string_literal: true

module Onni
  module Operations
    private

    def feature_operation(name, operation, **fields)
      Registry.require_definition!(name)
      payload = {feature_name: name.to_s, operation: operation, **fields}
      yield(payload)
      Store.bust_cache!(name)
      emit_operation(payload.merge(result: true))
      true
    end

    def emit_operation(payload)
      if adapter.respond_to?(:after_commit)
        adapter.after_commit do
          Store.bust_cache!(payload.fetch(:feature_name))
          Instrumenter.instrument("feature_operation", payload)
        end
      else
        Instrumenter.instrument("feature_operation", payload)
      end
    end
  end
end
