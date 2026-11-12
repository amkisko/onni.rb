# frozen_string_literal: true

module Onni
  module Adapters
    class Memory
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

      def gates_for_many(keys)
        @lock.synchronize do
          keys.each_with_object({}) do |key, loaded|
            loaded[key.to_s] = gates_for_unlocked(key.to_s)
          end
        end
      end

      def replace_gates(key, gates)
        @lock.synchronize { @gates[key.to_s] = gates.map { |gate| stringify(gate) } }
      end

      def add_gate(key, gate_key, value)
        @lock.synchronize do
          list = (@gates[key.to_s] ||= [])
          entry = {"key" => gate_key.to_s, "value" => value.to_s}
          list << entry unless list.any? { |gate| gate["key"] == entry["key"] && gate["value"] == entry["value"] }
        end
      end

      def remove_gate(key, gate_key, value = nil)
        @lock.synchronize do
          list = @gates[key.to_s]
          next if list.nil?

          list.reject! do |gate|
            gate["key"] == gate_key.to_s && (value.nil? || gate["value"] == value.to_s)
          end
        end
      end

      def clear_gates(key)
        @lock.synchronize { @gates[key.to_s] = [] }
      end

      def record_stat(key, enabled:, weight: 1)
        weight = weight.to_i.clamp(1, Stats::Sampler::MAX_WEIGHT)
        @lock.synchronize do
          bucket = (@stats[stat_bucket_key(key)] ||= {enabled: 0, disabled: 0})
          bucket[enabled ? :enabled : :disabled] += weight
        end
      end

      def record_stats_batch(buckets)
        @lock.synchronize do
          buckets.each do |feature_key, counts|
            bucket = (@stats[stat_bucket_key(feature_key)] ||= {enabled: 0, disabled: 0})
            bucket[:enabled] += counts[:enabled].to_i
            bucket[:disabled] += counts[:disabled].to_i
          end
        end
        buckets.size
      end

      def stats_for(key, period: "hour", from: 24.hours.ago, to: Time.current)
        @lock.synchronize do
          @stats.filter_map do |bucket_key, counts|
            feature_key, period_start = bucket_key.split("|", 2)
            next unless feature_key == key.to_s

            started = Time.parse("#{period_start} UTC")
            next unless started.between?(from, to)

            {
              "period_start" => started,
              "period" => period,
              "enabled_hits" => counts[:enabled],
              "disabled_hits" => counts[:disabled]
            }
          end
        end
      end

      def purge_stats_batch(older_than:, batch_size:, after_id: 0)
        @lock.synchronize do
          matching = @stats.keys.select { |bucket_key|
            _feature_key, period_start = bucket_key.split("|", 2)
            Time.parse("#{period_start} UTC") < older_than
          }.sort
          slice = matching.first(batch_size)
          slice.each { |bucket_key| @stats.delete(bucket_key) }
          return {deleted: 0, last_id: nil} if slice.empty?

          {deleted: slice.size, last_id: (slice.size == batch_size) ? (after_id + slice.size) : nil}
        end
      end

      def stats_overview
        @lock.synchronize do
          starts = @stats.keys.filter_map { |bucket_key|
            _feature_key, period_start = bucket_key.split("|", 2)
            Time.parse("#{period_start} UTC")
          }
          {
            bucket_count: @stats.size,
            oldest_period_start: starts.min
          }
        end
      end

      private

      def gates_for_unlocked(key)
        list = @gates[key]
        return EMPTY_GATES if list.nil? || list.empty?

        list.map(&:dup)
      end

      def stringify(gate)
        {"key" => gate[:key] || gate["key"], "value" => (gate[:value] || gate["value"]).to_s}
      end

      def stat_bucket_key(key)
        "#{key}|#{Time.now.utc.strftime("%Y-%m-%dT%H:00:00")}"
      end
    end
  end
end
