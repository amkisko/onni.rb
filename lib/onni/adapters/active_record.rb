# frozen_string_literal: true

module Onni
  module Adapters
    class ActiveRecord
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

      def record_stat(key, enabled:, weight: 1)
        weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
        upsert_stat_row(key.to_s, enabled: enabled, weight: weight)
      end

      def record_stats_batch(buckets)
        ::Onni::StatBucket.transaction do
          buckets.each do |feature_key, counts|
            enabled_weight = counts[:enabled].to_i
            disabled_weight = counts[:disabled].to_i
            upsert_stat_row(feature_key, enabled: true, weight: enabled_weight) if enabled_weight.positive?
            upsert_stat_row(feature_key, enabled: false, weight: disabled_weight) if disabled_weight.positive?
          end
        end
        buckets.size
      end

      def stats_for(key, period: "hour", from: 24.hours.ago, to: Time.current)
        ::Onni::StatBucket.where(feature_key: key.to_s, period: period, period_start: from..to)
          .order(:period_start).map do |bucket|
          {
            "period_start" => bucket.period_start,
            "period" => bucket.period,
            "enabled_hits" => bucket.enabled_hits,
            "disabled_hits" => bucket.disabled_hits
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

      private

      def upsert_stat_row(key, enabled:, weight:)
        weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
        period_start = Time.current.utc.beginning_of_hour
        now = Time.current
        column = enabled ? "enabled_hits" : "disabled_hits"
        # Intent: column conflict target matches index_onni_feature_stats_unique (SQLite + PostgreSQL ON CONFLICT).
        ::Onni::StatBucket.upsert(
          {
            feature_key: key.to_s,
            period: "hour",
            period_start: period_start,
            enabled_hits: enabled ? weight : 0,
            disabled_hits: enabled ? 0 : weight,
            created_at: now,
            updated_at: now
          },
          unique_by: %i[feature_key period period_start],
          on_duplicate: ::Arel.sql("#{column} = #{column} + #{weight}, updated_at = excluded.updated_at")
        )
      end
    end
  end
end
