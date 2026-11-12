# frozen_string_literal: true

module Onni
  module Migrator
    # In-memory source for Onni.migrate!. Wrap rows from any prior feature-flag store.
    class Snapshot
      attr_reader :feature_keys, :gates

      def initialize(feature_keys:, gates:)
        @feature_keys = Array(feature_keys)
        @gates = Array(gates)
      end
    end
  end
end
