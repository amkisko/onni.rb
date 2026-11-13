# frozen_string_literal: true

module Onni
  module Adapters
    class Memory
      module Statistics
        def record_stat(key, shown:, weight: 1)
          weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
          @lock.synchronize do
            bucket = (@stats[stat_bucket_key(key)] ||= {shown_count: 0, skip_count: 0})
            bucket[shown ? :shown_count : :skip_count] += weight
          end
        end

        def record_stats_batch(buckets)
          @lock.synchronize do
            buckets.each do |feature_key, counts|
              bucket = (@stats[stat_bucket_key(feature_key)] ||= {shown_count: 0, skip_count: 0})
              bucket[:shown_count] += counts[:shown_count].to_i
              bucket[:skip_count] += counts[:skip_count].to_i
            end
          end
          buckets.size
        end

        def stats_for(key, period: "hour", from: Time.now - 86_400, to: Time.now)
          return [] unless period == "hour"

          @lock.synchronize do
            @stats.filter_map do |bucket_key, counts|
              feature_key, hour = bucket_key
              next unless feature_key == key.to_s

              started = Time.at(hour * 3600).utc
              next unless started.between?(from, to)

              {
                "period_start" => started,
                "period" => period,
                "shown_count" => counts[:shown_count],
                "skip_count" => counts[:skip_count]
              }
            end
          end.sort_by { |bucket| bucket.fetch("period_start") }
        end

        def purge_stats_batch(older_than:, batch_size:, after_id: 0)
          @lock.synchronize do
            matching = older_stat_keys(older_than)
            slice = matching.first(batch_size)
            slice.each { |bucket_key| @stats.delete(bucket_key) }
            return {deleted: 0, last_id: nil} if slice.empty?

            {deleted: slice.size, last_id: (slice.size == batch_size) ? (after_id + slice.size) : nil}
          end
        end

        def stats_overview
          @lock.synchronize do
            starts = @stats.keys.filter_map { |bucket_key|
              _feature_key, hour = bucket_key
              Time.at(hour * 3600).utc
            }
            {
              bucket_count: @stats.size,
              oldest_period_start: starts.min
            }
          end
        end

        private

        def older_stat_keys(older_than)
          @stats.keys.select { |_feature_key, hour| Time.at(hour * 3600).utc < older_than }.sort
        end

        def stat_bucket_key(key)
          feature_key = key.is_a?(Symbol) ? key.to_s.freeze : key.to_s.dup.freeze
          [feature_key, Time.now.to_i / 3600]
        end
      end
    end
  end
end
