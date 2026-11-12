# frozen_string_literal: true

require "spec_helper"
require "active_support/testing/time_helpers"

RSpec.describe Onni::Stats::Purge do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    previous_retention = Onni.configuration.stats_retention
    example.run
  ensure
    Onni.configuration.stats_retention = previous_retention
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_retention = 30.days
  end

  def seed_bucket(feature_key, period_start)
    travel_to(period_start) do
      Onni.adapter.record_stat(feature_key, enabled: true)
    end
  end

  it "deletes buckets older than the retention cutoff" do
    seed_bucket("demo", 40.days.ago)
    seed_bucket("demo", 10.days.ago)

    result = described_class.call

    expect(result[:continued]).to be(false)
    expect(result[:processed_count]).to eq(1)
    expect(Onni::Stats.for("demo", from: 60.days.ago).size).to eq(1)
  end

  it "accepts an explicit older_than cutoff" do
    seed_bucket("demo", 5.days.ago)
    seed_bucket("demo", 1.day.ago)

    result = described_class.call(older_than: 3.days.ago)

    expect(result[:processed_count]).to eq(1)
    expect(Onni::Stats.for("demo", from: 10.days.ago).map { |row| row["enabled_hits"] }).to eq([1])
  end

  it "pages through batches and enqueues the next page when enqueue is present" do
    3.times { |index| seed_bucket("demo", (40 + index).days.ago) }
    enqueued = []

    result = described_class.call(
      older_than: 30.days.ago,
      batch_size: 2,
      enqueue: ->(**kwargs) { enqueued << kwargs }
    )

    expect(result[:continued]).to be(true)
    expect(result[:processed_count]).to eq(2)
    expect(enqueued.size).to eq(1)
    expect(enqueued.first[:processed_count]).to eq(2)

    described_class.call(**enqueued.first, enqueue: nil)
    expect(Onni::Stats.for("demo", from: 60.days.ago)).to eq([])
  end

  it "drains all pages in one call when enqueue is absent" do
    3.times { |index| seed_bucket("demo", (40 + index).days.ago) }

    result = described_class.call(older_than: 30.days.ago, batch_size: 2)

    expect(result[:continued]).to be(false)
    expect(result[:processed_count]).to eq(3)
    expect(Onni::Stats.for("demo", from: 60.days.ago)).to eq([])
  end

  it "raises when neither older_than nor stats_retention is set" do
    Onni.configuration.stats_retention = nil
    expect { described_class.call }.to raise_error(ArgumentError, /stats_retention/)
  end
end
