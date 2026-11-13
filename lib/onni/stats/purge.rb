# frozen_string_literal: true

module Onni
  module Stats
    # Deletes hourly hit buckets older than a cutoff, in id-ordered batches.
    # With enqueue, one batch runs then the next page is scheduled.
    # Without enqueue (console `Purge.call`), remaining pages drain in-process.
    class Purge
      DEFAULT_BATCH_SIZE = 1_000

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(older_than: nil, batch_size: DEFAULT_BATCH_SIZE, after_id: 0, processed_count: 0, enqueue: nil)
        @older_than = older_than
        @batch_size = batch_size
        @after_id = after_id
        @processed_count = processed_count
        @enqueue = enqueue
      end

      def call
        older_than = resolve_older_than
        processed = @processed_count
        after_id = @after_id

        loop do
          batch = Onni.adapter.purge_stats_batch(
            older_than: older_than,
            batch_size: @batch_size,
            after_id: after_id
          )
          processed += batch[:deleted]
          break if batch[:last_id].nil?

          if @enqueue
            @enqueue.call(
              older_than: older_than,
              batch_size: @batch_size,
              after_id: batch[:last_id],
              processed_count: processed
            )
            return {
              deleted: processed - @processed_count,
              processed_count: processed,
              after_id: batch[:last_id],
              continued: true
            }
          end

          after_id = batch[:last_id]
        end

        {
          deleted: processed - @processed_count,
          processed_count: processed,
          after_id: after_id,
          continued: false
        }
      end

      private

      def resolve_older_than
        return @older_than if @older_than

        retention = Onni.configuration.stats_retention
        if retention.nil?
          raise ArgumentError, "Pass older_than: or set Onni.configuration.stats_retention"
        end

        Time.now - retention
      end
    end
  end
end
