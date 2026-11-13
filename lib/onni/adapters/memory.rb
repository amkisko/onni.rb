# frozen_string_literal: true

require "onni/adapters/memory/statistics"

module Onni
  module Adapters
    class Memory
      include Statistics

      EMPTY_GATES = [].freeze

      def initialize(lock: Sync.new_lock)
        @features = {}
        @gates = {}
        @stats = {}
        @lock = lock
      end

      def clear!
        @lock.synchronize do
          @features.clear
          @gates.clear
          @stats.clear
        end
      end

      def add(key)
        @lock.synchronize { @features[key.to_s] = true }
      end

      def exist?(key)
        @lock.synchronize do
          @features.key?(key.to_s) || @gates.fetch(key.to_s, []).any?
        end
      end

      def feature_keys
        @lock.synchronize do
          (@features.keys + @gates.select { |_key, gates| gates.any? }.keys).uniq.sort
        end
      end

      def gates_for(key)
        @lock.synchronize { gates_for_unlocked(key.to_s) }
      end

      def gates_snapshot_for(key)
        @lock.synchronize { @gates.fetch(key.to_s, EMPTY_GATES) }
      end

      def gates_for_many(keys)
        @lock.synchronize do
          keys.each_with_object({}) do |key, loaded|
            loaded[key.to_s] = gates_for_unlocked(key.to_s)
          end
        end
      end

      def replace_gates(key, gates)
        @lock.synchronize { @gates[key.to_s] = freeze_gates(gates) }
      end

      def update_gates(key)
        @lock.synchronize do
          gates = gates_for_unlocked(key.to_s)
          gates = gates.dup if gates.frozen?
          yield gates
          @gates[key.to_s] = freeze_gates(gates)
        end
      end

      def add_gate(key, gate_key, value)
        @lock.synchronize do
          list = @gates.fetch(key.to_s, EMPTY_GATES).dup
          entry = {"key" => gate_key.to_s, "value" => value.to_s}
          list << entry unless list.any? { |gate| gate["key"] == entry["key"] && gate["value"] == entry["value"] }
          @gates[key.to_s] = freeze_gates(list)
        end
      end

      def remove_gate(key, gate_key, value = nil)
        @lock.synchronize do
          list = @gates[key.to_s]
          next if list.nil?

          @gates[key.to_s] = list.reject do |gate|
            gate["key"] == gate_key.to_s && (value.nil? || gate["value"] == value.to_s)
          end.freeze
        end
      end

      def clear_gates(key)
        @lock.synchronize { @gates[key.to_s] = EMPTY_GATES }
      end

      private

      def gates_for_unlocked(key)
        list = @gates[key]
        return EMPTY_GATES if list.nil? || list.empty?

        list.map { |gate| {"key" => gate["key"].dup, "value" => gate["value"].dup} }
      end

      def freeze_gates(gates)
        gates.map do |gate|
          key = (gate[:key] || gate["key"]).to_s
          value = (gate[:value] || gate["value"]).to_s
          {
            "key" => key.frozen? ? key : key.dup.freeze,
            "value" => value.frozen? ? value : value.dup.freeze
          }.freeze
        end.freeze
      end
    end
  end
end
