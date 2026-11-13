# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::VisibilityChart do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.utc(2026, 11, 12, 12, 30))
    example.run
  ensure
    travel_back
  end

  def record_at(time, shown:, weight:)
    travel_to(time) { Onni.adapter.record_stat("demo", shown: shown, weight: weight) }
  end

  it "fills chronological hours and includes the current partial hour" do
    record_at(Time.current, shown: true, weight: 6)
    record_at(23.hours.ago.beginning_of_hour, shown: false, weight: 2)
    record_at(24.hours.ago.beginning_of_hour, shown: true, weight: 100)
    record_at(1.hour.from_now, shown: true, weight: 100)
    Onni.adapter.record_stat("search_v2", shown: true, weight: 100)

    chart = described_class.new("demo")

    expect(chart.rows.size).to eq(24)
    expect(chart.rows.first).to include("period_start" => Time.utc(2026, 11, 11, 13), "skip_count" => 2)
    expect(chart.rows[1]).to include("shown_count" => 0, "skip_count" => 0)
    expect(chart.rows.last).to include("period_start" => Time.current.beginning_of_hour, "shown_count" => 6)
    expect(chart.shown_count).to eq(6)
    expect(chart.skip_count).to eq(2)
    expect(chart.shown_share).to eq(0.75)
  end

  %w[7d 30d].each do |range|
    it "aggregates #{range} into UTC days with a bounded history window" do
      days = (range == "7d") ? 7 : 30
      record_at(Time.current, shown: true, weight: 3)
      record_at(Time.current.beginning_of_day, shown: false, weight: 1)
      record_at((days - 1).days.ago.beginning_of_day, shown: true, weight: 2)
      record_at(days.days.ago.end_of_day, shown: true, weight: 100)

      chart = described_class.new("demo", range: range)

      expect(chart.rows.size).to eq(days)
      expect(chart.rows.first["shown_count"]).to eq(2)
      expect(chart.rows.last).to include("shown_count" => 3, "skip_count" => 1)
      expect(chart.shown_count).to eq(5)
      expect(chart.skip_count).to eq(1)
    end
  end

  it "sorts and aggregates unordered memory-adapter history" do
    Onni.adapter = Onni::Adapters::Memory.new
    record_at(Time.current, shown: false, weight: 4)
    record_at(1.hour.ago, shown: true, weight: 2)

    chart = described_class.new("demo")

    expect(chart.rows.last["skip_count"]).to eq(4)
    expect(chart.rows[-2]["shown_count"]).to eq(2)
    expect(chart.shown_share).to be_within(0.01).of(1.0 / 3)
  end

  it "keeps daily boundaries in UTC when the application uses another time zone" do
    Time.use_zone("Europe/Helsinki") do
      record_at(Time.utc(2026, 11, 11, 23, 30), shown: true, weight: 2)
      record_at(Time.utc(2026, 11, 12, 0, 30), shown: false, weight: 3)

      chart = described_class.new("demo", range: "7d")

      expect(chart.rows[-2]).to include("period_start" => Time.utc(2026, 11, 11), "shown_count" => 2, "skip_count" => 0)
      expect(chart.rows.last).to include("period_start" => Time.utc(2026, 11, 12), "shown_count" => 0, "skip_count" => 3)
    end
  end

  it "has zero totals and no percentage when there are no recorded evaluations" do
    chart = described_class.new("demo")

    expect(chart.shown_count).to eq(0)
    expect(chart.skip_count).to eq(0)
    expect(chart.shown_share).to be_nil
    expect(chart.maximum).to eq(1)
    expect(chart.points("shown_count").split.map { |point| point.split(",").last.to_f }.uniq).to eq([208.0])
  end

  it "plots both series on the same scale with zero hours on the baseline" do
    record_at(Time.current, shown: true, weight: 8)
    record_at(Time.current, shown: false, weight: 4)
    chart = described_class.new("demo")

    shown = chart.points("shown_count").split.map { |point| point.split(",").map(&:to_f) }
    skipped = chart.points("skip_count").split.map { |point| point.split(",").map(&:to_f) }

    expect(shown.first).to eq([56.0, 208.0])
    expect(shown.last).to eq([776.0, 24.0])
    expect(skipped.last).to eq([776.0, 116.0])
  end

  it "rejects unsupported windows" do
    expect { described_class.new("demo", range: "365d") }.to raise_error(ArgumentError)
  end

  it "rejects unknown series" do
    expect { described_class.new("demo").points("actors") }.to raise_error(ArgumentError)
  end
end
