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

          requested_key = key.to_s
          hours = epoch_hours(from).ceil..epoch_hours(to).floor
          @lock.synchronize do
            @stats.filter_map do |(feature_key, hour), counts|
              stat_row(hour, period, counts) if feature_key == requested_key && hours.cover?(hour)
            end
          end.sort_by { |bucket| bucket.fetch("period_start") }
        end

        def purge_stats_batch(older_than:, batch_size:, after_id: 0)
          cutoff_hour = epoch_hours(older_than).ceil
          @lock.synchronize do
            expired = @stats.each_key.lazy.select { |key| key.last < cutoff_hour }.first(batch_size)
            expired.each { |bucket_key| @stats.delete(bucket_key) }
            return {deleted: 0, last_id: nil} if expired.empty?

            {deleted: expired.size, last_id: (expired.size == batch_size) ? (after_id + expired.size) : nil}
          end
        end

        def stats_overview
          @lock.synchronize do
            oldest = @stats.each_key.min_by(&:last)
            {
              bucket_count: @stats.size,
              oldest_period_start: oldest && Time.at(oldest.last * 3600).utc
            }
          end
        end

        private

        def epoch_hours(time)
          time.to_time.to_r / 3600
        end

        def stat_row(hour, period, counts)
          {"period_start" => Time.at(hour * 3600).utc, "period" => period,
           "shown_count" => counts[:shown_count], "skip_count" => counts[:skip_count]}
        end

        def stat_bucket_key(key)
          [-key.to_s, Time.now.to_i / 3600]
        end
      end
    end
  end
end
