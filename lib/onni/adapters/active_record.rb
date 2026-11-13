# frozen_string_literal: true

require "onni/adapters/active_record/stat_writes"

module Onni
  module Adapters
    class ActiveRecord
      include StatWrites

      def add(key)
        ::Onni::Feature.find_or_create_by!(key: key.to_s)
      end

      def exist?(key)
        ::Onni::Feature.where(key: key.to_s).exists? ||
          ::Onni::Gate.where(feature_key: key.to_s).exists?
      end

      def feature_keys
        (
          ::Onni::Feature.pluck(:key) +
            ::Onni::Gate.distinct.pluck(:feature_key)
        ).uniq.sort
      end

      def gates_for(key)
        ::Onni::Gate.where(feature_key: key.to_s).map { |gate| {"key" => gate.key, "value" => gate.value} }
      end

      def gates_for_many(keys)
        keys = keys.map(&:to_s)
        grouped = ::Onni::Gate.where(feature_key: keys).group_by(&:feature_key)
        keys.each_with_object({}) do |key, loaded|
          loaded[key] = Array(grouped[key]).map { |gate| {"key" => gate.key, "value" => gate.value} }
        end
      end

      def replace_gates(key, gates)
        ::Onni::Gate.transaction do
          ::Onni::Gate.where(feature_key: key.to_s).delete_all
          gates.each { |gate| add_gate(key, gate[:key] || gate["key"], gate[:value] || gate["value"]) }
        end
      end

      def update_gates(key)
        ::Onni::Feature.transaction do
          ::Onni::Feature.lock.find_by!(key: key.to_s)
          gates = gates_for(key)
          yield gates
          replace_gates(key, gates)
        end
      end

      def add_gate(key, gate_key, value)
        ::Onni::Gate.find_or_create_by!(feature_key: key.to_s, key: gate_key.to_s, value: value.to_s)
      end

      def remove_gate(key, gate_key, value = nil)
        scope = ::Onni::Gate.where(feature_key: key.to_s, key: gate_key.to_s)
        scope = scope.where(value: value.to_s) unless value.nil?
        scope.delete_all
      end

      def clear_gates(key)
        ::Onni::Gate.where(feature_key: key.to_s).delete_all
      end

      def stats_for(key, period: "hour", from: 24.hours.ago, to: Time.current)
        ::Onni::StatBucket.where(feature_key: key.to_s, period: period, period_start: from..to)
          .order(:period_start).map do |bucket|
          {
            "period_start" => bucket.period_start,
            "period" => bucket.period,
            "shown_count" => bucket.shown_count,
            "skip_count" => bucket.skip_count
          }
        end
      end

      def purge_stats_batch(older_than:, batch_size:, after_id: 0)
        ids = ::Onni::StatBucket
          .where(period_start: ...older_than)
          .where("id > ?", after_id)
          .order(:id)
          .limit(batch_size)
          .pluck(:id)
        return {deleted: 0, last_id: nil} if ids.empty?

        deleted = ::Onni::StatBucket.where(id: ids).delete_all
        {deleted: deleted, last_id: ids.last}
      end

      def stats_overview
        {
          bucket_count: ::Onni::StatBucket.count,
          oldest_period_start: ::Onni::StatBucket.minimum(:period_start)
        }
      end
    end
  end
end
