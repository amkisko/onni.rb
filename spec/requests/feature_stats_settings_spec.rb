# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Persisted feature statistics settings", type: :request do
  it "records pending evaluations without creating a power decision" do
    expect(Onni.visible?(:demo)).to be(false)
    expect(Onni.pending?(:demo)).to be(true)
    expect(Onni::StatBucket.where(feature_key: "demo").sum(:skip_count)).to eq(1)
    expect(Onni::Gate.where(feature_key: "demo")).not_to exist
    expect(Onni.visible?(:missing)).to be(false)
    expect(Onni::StatBucket.where(feature_key: "missing")).not_to exist
  end

  it "persists feature policy, invalidates preloads, and rebuilds it after cache loss" do
    Onni.configuration.cache = ActiveSupport::Cache::MemoryStore.new
    Onni.ready!(:demo)
    Onni.preload!(:demo)
    Onni.stats!(:demo, enabled: false, sample_rate: 0.5)
    expect(Onni.visible?(:demo)).to be(true)
    expect(Onni::StatBucket.count).to eq(0)
    allow(Random).to receive(:rand).and_return(0.01)
    expect(Onni.visible?(:demo, record_stats: true)).to be(true)
    expect(Onni::StatBucket.sum(:shown_count)).to eq(2)
    Onni.reset_adapter!
    Onni.configuration.cache.clear
    Onni.reset_request!
    expect(Onni[:demo].stats_settings).to eq("enabled" => false, "sample_rate" => 0.5)
    Onni.park!(:demo)
    expect(Onni.visible?(:demo)).to be(false)
    expect(Onni::StatBucket.sum(:skip_count)).to eq(0)
    Onni.stats!(:demo, enabled: nil, sample_rate: nil)
    expect(Onni.parked?(:demo)).to be(true)
    expect(Onni.visible?(:demo)).to be(false)
    expect(Onni::StatBucket.sum(:skip_count)).to eq(1)
  end

  it "fails closed for corrupt stats overrides while keeping evaluation results" do
    ["{bad", "[]", '{"enabled":"false"}', '{"sample_rate":2}'].each do |value|
      Onni.adapter.replace_gates(:demo, [{key: "powered", value: "true"}, {key: "stats", value: value}])
      expect(Onni.visible?(:demo, record_stats: true)).to be(true)
      expect(Onni[:demo].stats_settings).to eq("enabled" => false, "sample_rate" => 0.0)
    end
    expect(Onni::StatBucket.count).to eq(0)
  end

  it "flushes pending counts when buffering is switched off before request cleanup" do
    Onni.configuration.stats_buffer = true
    Onni.visible?(:demo)
    expect(Onni::StatBucket.count).to eq(0)
    Onni.configuration.stats_buffer = false
    Onni.reset_request!
    expect(Onni::StatBucket.sum(:skip_count)).to eq(1)
  end
end
