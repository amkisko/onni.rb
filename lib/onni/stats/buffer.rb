# frozen_string_literal: true

module Onni
  module Stats
    # Coalesces hit weights per feature until flush (request end / host job).
    module Buffer
      module_function

      def add(name, shown:, weight:)
        buckets = RequestStore.stats_buffer ||= {}
        key = name.to_s
        bucket = (buckets[key] ||= {shown_count: 0, skip_count: 0})
        bucket[shown ? :shown_count : :skip_count] += weight.to_i
      end

      def flush!
        buckets = RequestStore.stats_buffer
        RequestStore.stats_buffer = nil
        return 0 if buckets.nil? || buckets.empty?

        adapter = Onni.adapter
        if adapter.respond_to?(:record_stats_batch)
          adapter.record_stats_batch(buckets)
        else
          buckets.each do |feature_key, counts|
            flush_count(adapter, feature_key, shown: true, count: counts[:shown_count])
            flush_count(adapter, feature_key, shown: false, count: counts[:skip_count])
          end
        end
        buckets.size
      end

      def flush_count(adapter, feature_key, shown:, count:)
        # Individual writes cap sample weights; split aggregates to preserve their sum.
        while count.positive?
          weight = [count, Sampler::MAX_WEIGHT].min
          adapter.record_stat(feature_key, shown: shown, weight: weight)
          count -= weight
        end
      end
      private_class_method :flush_count
    end
  end
end
