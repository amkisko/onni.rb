# frozen_string_literal: true

module Onni
  module Adapters
    class ActiveRecord
      # Hit-bucket upsert helpers for the ActiveRecord adapter.
      module StatWrites
        def record_stat(key, enabled:, weight: 1)
          weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
          upsert_stat_row(key.to_s, enabled: enabled, weight: weight)
        end

        def record_stats_batch(buckets)
          rows = batch_stat_rows(buckets)
          return 0 if rows.empty?

          table = ::Onni::StatBucket.table_name
          # Intent: one statement for the flush; both hit columns use excluded.* so
          # PostgreSQL stays unambiguous and multi-flag request ends stay O(1) round-trips.
          ::Onni::StatBucket.upsert_all(
            rows,
            unique_by: %i[feature_key period period_start],
            on_duplicate: ::Arel.sql(
              "enabled_hits = #{table}.enabled_hits + excluded.enabled_hits, " \
              "disabled_hits = #{table}.disabled_hits + excluded.disabled_hits, " \
              "updated_at = excluded.updated_at"
            )
          )
          rows.size
        end

        private

        def batch_stat_rows(buckets)
          period_start = Time.current.utc.beginning_of_hour
          now = Time.current
          buckets.filter_map do |feature_key, counts|
            enabled_weight = counts[:enabled].to_i.clamp(0, Stats::Sampler::MAX_WEIGHT)
            disabled_weight = counts[:disabled].to_i.clamp(0, Stats::Sampler::MAX_WEIGHT)
            next if enabled_weight <= 0 && disabled_weight <= 0

            {
              feature_key: feature_key.to_s,
              period: "hour",
              period_start: period_start,
              enabled_hits: enabled_weight,
              disabled_hits: disabled_weight,
              created_at: now,
              updated_at: now
            }
          end
        end

        def upsert_stat_row(key, enabled:, weight:)
          weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
          period_start = Time.current.utc.beginning_of_hour
          now = Time.current
          column = enabled ? "enabled_hits" : "disabled_hits"
          table = ::Onni::StatBucket.table_name
          # Intent: unique_by matches index_onni_feature_stats_unique. Qualify the existing-row
          # column on the RHS; bare names are ambiguous with excluded on PostgreSQL ON CONFLICT.
          # SET targets stay bare (PostgreSQL rejects table-qualified assignment targets).
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
            on_duplicate: ::Arel.sql(
              "#{column} = #{table}.#{column} + #{weight}, updated_at = excluded.updated_at"
            )
          )
        end
      end
    end
  end
end
