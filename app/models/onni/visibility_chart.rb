# frozen_string_literal: true

module Onni
  class VisibilityChart
    WINDOWS = {"24h" => 24, "7d" => 168, "30d" => 720}.freeze

    attr_reader :range, :from, :to, :rows, :shown_count, :skip_count

    def initialize(name, range: "24h")
      raise ArgumentError, "Unsupported evaluation history range" unless WINDOWS.key?(range)

      @range = range
      @to = Time.current.utc
      @from = period_start(to) - (period_count - 1) * interval
      load_history(name)
    end

    def hourly?
      range == "24h"
    end

    def shown_share
      total = shown_count + skip_count
      shown_count.fdiv(total) if total.positive?
    end

    def maximum
      [1, rows.flat_map { |row| row.values_at("shown_count", "skip_count") }.max].max
    end

    def points(column)
      raise ArgumentError, "Unknown evaluation series" unless %w[shown_count skip_count].include?(column)

      peak = maximum
      rows.each_with_index.map do |row, index|
        point(row.fetch(column), index, peak)
      end.join(" ")
    end

    private

    def load_history(name)
      @rows = build_rows(Onni::Stats.for(name, from: from, to: to))
      @shown_count = rows.sum { |row| row.fetch("shown_count") }
      @skip_count = rows.sum { |row| row.fetch("skip_count") }
    end

    def interval
      hourly? ? 1.hour : 1.day
    end

    def period_count
      hourly? ? WINDOWS.fetch(range) : WINDOWS.fetch(range) / 24
    end

    def period_start(time)
      hourly? ? time.utc.beginning_of_hour : time.utc.beginning_of_day
    end

    def point(value, index, peak)
      x = 56 + 720 * index.fdiv(rows.size - 1)
      y = 208 - 184 * value.fdiv(peak)
      format("%.2f,%.2f", x, y)
    end

    def build_rows(buckets)
      grouped = buckets.group_by { |bucket| period_start(bucket.fetch("period_start")) }
      Array.new(period_count) do |index|
        started = from + index * interval
        period_row(started, grouped.fetch(started, []))
      end
    end

    def period_row(started, samples)
      {
        "period_start" => started,
        "shown_count" => samples.sum { |sample| sample.fetch("shown_count") },
        "skip_count" => samples.sum { |sample| sample.fetch("skip_count") }
      }
    end
  end
end
