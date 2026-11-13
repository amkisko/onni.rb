# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::Adapters::ActiveRecord, "#record_stats_batch" do
  subject(:adapter) { described_class.new }

  it "writes multiple features in one upsert_all" do
    expect(Onni::StatBucket).to receive(:upsert_all).once.and_call_original

    result = adapter.record_stats_batch(
      "alpha" => {enabled: 2, disabled: 1},
      "beta" => {enabled: 3, disabled: 0}
    )

    expect(result).to eq(2)
    expect(Onni::StatBucket.find_by!(feature_key: "alpha")).to have_attributes(enabled_hits: 2, disabled_hits: 1)
    expect(Onni::StatBucket.find_by!(feature_key: "beta")).to have_attributes(enabled_hits: 3, disabled_hits: 0)
  end

  it "increments both hit columns on a second batch for the same hour" do
    adapter.record_stats_batch("demo" => {enabled: 2, disabled: 1})
    adapter.record_stats_batch("demo" => {enabled: 3, disabled: 4})

    expect(Onni::StatBucket.find_by!(feature_key: "demo")).to have_attributes(enabled_hits: 5, disabled_hits: 5)
  end

  it "returns zero and skips upsert_all for empty weights" do
    expect(Onni::StatBucket).not_to receive(:upsert_all)
    expect(adapter.record_stats_batch("demo" => {enabled: 0, disabled: 0})).to eq(0)
    expect(Onni::StatBucket.count).to eq(0)
  end

  it "emits excluded hit increments in the conflict update" do
    sql = []
    allow(Onni::StatBucket).to receive(:upsert_all).and_wrap_original do |original, *args, **kwargs|
      sql << kwargs[:on_duplicate].to_s
      original.call(*args, **kwargs)
    end

    adapter.record_stats_batch("demo" => {enabled: 1, disabled: 1})
    joined = sql.join(" ")
    expect(joined).to include("enabled_hits = onni_feature_stat_buckets.enabled_hits + excluded.enabled_hits")
    expect(joined).to include("disabled_hits = onni_feature_stat_buckets.disabled_hits + excluded.disabled_hits")
  end
end
