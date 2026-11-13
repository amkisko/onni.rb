# frozen_string_literal: true

module Onni
  module Stats
    # Operator-facing storage summary so retention and growth stay visible.
    module Overview
      ROW_WARNING = 1_000_000

      module_function

      def call
        raw = Onni.adapter.stats_overview
        retention = Onni.configuration.stats_retention
        oldest = raw[:oldest_period_start]
        past_retention =
          if oldest && retention
            oldest < Time.now - retention
          else
            false
          end

        {
          bucket_count: raw[:bucket_count].to_i,
          oldest_period_start: oldest,
          retention: retention,
          sample_rate: Onni.configuration.stats_sample_rate,
          scale_sampled_hits: Onni.configuration.stats_scale_sampled_hits,
          past_retention: past_retention,
          large_table: raw[:bucket_count].to_i >= ROW_WARNING
        }
      end
    end
  end
end
