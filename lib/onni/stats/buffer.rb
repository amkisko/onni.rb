# frozen_string_literal: true

module Onni
  module Stats
    # Coalesces hit weights per feature until flush (request end / host job).
    module Buffer
      module_function

      def add(name, enabled:, weight:)
        buckets = RequestStore.stats_buffer || {}
        key = name.to_s
        bucket = (buckets[key] ||= {enabled: 0, disabled: 0})
        bucket[enabled ? :enabled : :disabled] += weight.to_i
        RequestStore.stats_buffer = buckets
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
            adapter.record_stat(feature_key, enabled: true, weight: counts[:enabled]) if counts[:enabled].positive?
            adapter.record_stat(feature_key, enabled: false, weight: counts[:disabled]) if counts[:disabled].positive?
          end
        end
        buckets.size
      end
    end
  end
end
