# frozen_string_literal: true

module Onni
  module Adapters
    class ActiveRecord
      # Hit-bucket upsert helpers for the ActiveRecord adapter.
      module StatWrites
        def record_stat(key, shown:, weight: 1)
          weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
          upsert_stat_row(key.to_s, shown: shown, weight: weight)
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
              "shown_count = #{table}.shown_count + excluded.shown_count, " \
              "skip_count = #{table}.skip_count + excluded.skip_count, " \
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
            shown_weight = [counts[:shown_count].to_i, 0].max
            skip_weight = [counts[:skip_count].to_i, 0].max
            next if shown_weight <= 0 && skip_weight <= 0

            {
              feature_key: feature_key.to_s,
              period: "hour",
              period_start: period_start,
              shown_count: shown_weight,
              skip_count: skip_weight,
              created_at: now,
              updated_at: now
            }
          end
        end

        def upsert_stat_row(key, shown:, weight:)
          weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
          period_start = Time.current.utc.beginning_of_hour
          now = Time.current
          column = shown ? "shown_count" : "skip_count"
          table = ::Onni::StatBucket.table_name
          # Intent: unique_by matches index_onni_feature_stats_unique. Qualify the existing-row
          # column on the RHS; bare names are ambiguous with excluded on PostgreSQL ON CONFLICT.
          # SET targets stay bare (PostgreSQL rejects table-qualified assignment targets).
          ::Onni::StatBucket.upsert(
            {
              feature_key: key.to_s,
              period: "hour",
              period_start: period_start,
              shown_count: shown ? weight : 0,
              skip_count: shown ? 0 : weight,
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
