# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::Adapters::ActiveRecord, "#record_stats_batch" do
  subject(:adapter) { described_class.new }

  it "writes multiple features in one upsert_all" do
    expect(Onni::StatBucket).to receive(:upsert_all).once.and_call_original

    result = adapter.record_stats_batch(
      "alpha" => {shown_count: 2, skip_count: 1},
      "beta" => {shown_count: 3, skip_count: 0}
    )

    expect(result).to eq(2)
    expect(Onni::StatBucket.find_by!(feature_key: "alpha")).to have_attributes(shown_count: 2, skip_count: 1)
    expect(Onni::StatBucket.find_by!(feature_key: "beta")).to have_attributes(shown_count: 3, skip_count: 0)
  end

  it "increments both hit columns on a second batch for the same hour" do
    adapter.record_stats_batch("demo" => {shown_count: 2, skip_count: 1})
    adapter.record_stats_batch("demo" => {shown_count: 3, skip_count: 4})

    expect(Onni::StatBucket.find_by!(feature_key: "demo")).to have_attributes(shown_count: 5, skip_count: 5)
  end

  it "preserves summed sample weights larger than one evaluation's weight limit" do
    adapter.record_stats_batch("demo" => {shown_count: 1_000_007, skip_count: 2_000_009})
    expect(Onni::StatBucket.find_by!(feature_key: "demo")).to have_attributes(shown_count: 1_000_007, skip_count: 2_000_009)
  end

  it "returns zero and skips upsert_all for empty weights" do
    expect(Onni::StatBucket).not_to receive(:upsert_all)
    expect(adapter.record_stats_batch("demo" => {shown_count: 0, skip_count: 0})).to eq(0)
    expect(Onni::StatBucket.count).to eq(0)
  end

  it "emits excluded hit increments in the conflict update" do
    sql = []
    allow(Onni::StatBucket).to receive(:upsert_all).and_wrap_original do |original, *args, **kwargs|
      sql << kwargs[:on_duplicate].to_s
      original.call(*args, **kwargs)
    end

    adapter.record_stats_batch("demo" => {shown_count: 1, skip_count: 1})
    joined = sql.join(" ")
    expect(joined).to include("shown_count = onni_feature_stat_buckets.shown_count + excluded.shown_count")
    expect(joined).to include("skip_count = onni_feature_stat_buckets.skip_count + excluded.skip_count")
  end
end
