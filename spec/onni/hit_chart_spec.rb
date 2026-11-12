# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::HitChart do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.utc(2026, 11, 12, 12, 30))
    example.run
  ensure
    travel_back
  end

  def record_at(time, enabled:, weight:)
    travel_to(time) { Onni.adapter.record_stat("demo", enabled: enabled, weight: weight) }
  end

  it "fills chronological hours and includes the current partial hour" do
    record_at(Time.current, enabled: true, weight: 6)
    record_at(23.hours.ago.beginning_of_hour, enabled: false, weight: 2)
    record_at(24.hours.ago.beginning_of_hour, enabled: true, weight: 100)
    record_at(1.hour.from_now, enabled: true, weight: 100)
    Onni.adapter.record_stat("search_v2", enabled: true, weight: 100)

    chart = described_class.new("demo")

    expect(chart.rows.size).to eq(24)
    expect(chart.rows.first).to include("period_start" => Time.utc(2026, 11, 11, 13), "disabled_hits" => 2)
    expect(chart.rows[1]).to include("enabled_hits" => 0, "disabled_hits" => 0)
    expect(chart.rows.last).to include("period_start" => Time.current.beginning_of_hour, "enabled_hits" => 6)
    expect(chart.enabled_hits).to eq(6)
    expect(chart.disabled_hits).to eq(2)
    expect(chart.enabled_percentage).to eq(75.0)
  end

  %w[7d 30d].each do |range|
    it "aggregates #{range} into UTC days with a bounded history window" do
      days = (range == "7d") ? 7 : 30
      record_at(Time.current, enabled: true, weight: 3)
      record_at(Time.current.beginning_of_day, enabled: false, weight: 1)
      record_at((days - 1).days.ago.beginning_of_day, enabled: true, weight: 2)
      record_at(days.days.ago.end_of_day, enabled: true, weight: 100)

      chart = described_class.new("demo", range: range)

      expect(chart.rows.size).to eq(days)
      expect(chart.rows.first["enabled_hits"]).to eq(2)
      expect(chart.rows.last).to include("enabled_hits" => 3, "disabled_hits" => 1)
      expect(chart.enabled_hits).to eq(5)
      expect(chart.disabled_hits).to eq(1)
    end
  end

  it "sorts and aggregates unordered memory-adapter history" do
    Onni.adapter = Onni::Adapters::Memory.new
    record_at(Time.current, enabled: false, weight: 4)
    record_at(1.hour.ago, enabled: true, weight: 2)

    chart = described_class.new("demo")

    expect(chart.rows.last["disabled_hits"]).to eq(4)
    expect(chart.rows[-2]["enabled_hits"]).to eq(2)
    expect(chart.enabled_percentage).to be_within(0.01).of(100.0 / 3)
  end

  it "keeps daily boundaries in UTC when the application uses another time zone" do
    Time.use_zone("Europe/Helsinki") do
      record_at(Time.utc(2026, 11, 11, 23, 30), enabled: true, weight: 2)
      record_at(Time.utc(2026, 11, 12, 0, 30), enabled: false, weight: 3)

      chart = described_class.new("demo", range: "7d")

      expect(chart.rows[-2]).to include("period_start" => Time.utc(2026, 11, 11), "enabled_hits" => 2, "disabled_hits" => 0)
      expect(chart.rows.last).to include("period_start" => Time.utc(2026, 11, 12), "enabled_hits" => 0, "disabled_hits" => 3)
    end
  end

  it "has zero totals and no percentage when there are no recorded evaluations" do
    chart = described_class.new("demo")

    expect(chart.enabled_hits).to eq(0)
    expect(chart.disabled_hits).to eq(0)
    expect(chart.enabled_percentage).to be_nil
    expect(chart.maximum).to eq(1)
    expect(chart.points("enabled_hits").split.map { |point| point.split(",").last.to_f }.uniq).to eq([208.0])
  end

  it "plots both series on the same scale with zero hours on the baseline" do
    record_at(Time.current, enabled: true, weight: 8)
    record_at(Time.current, enabled: false, weight: 4)
    chart = described_class.new("demo")

    enabled = chart.points("enabled_hits").split.map { |point| point.split(",").map(&:to_f) }
    disabled = chart.points("disabled_hits").split.map { |point| point.split(",").map(&:to_f) }

    expect(enabled.first).to eq([56.0, 208.0])
    expect(enabled.last).to eq([776.0, 24.0])
    expect(disabled.last).to eq([776.0, 116.0])
  end

  it "rejects unsupported windows" do
    expect { described_class.new("demo", range: "365d") }.to raise_error(ArgumentError)
  end

  it "rejects unknown series" do
    expect { described_class.new("demo").points("actors") }.to raise_error(ArgumentError)
  end
end
