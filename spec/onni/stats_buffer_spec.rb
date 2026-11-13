# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Stats::Buffer do
  around do |example|
    previous = {
      stats_enabled: Onni.configuration.stats_enabled,
      stats_sample_rate: Onni.configuration.stats_sample_rate,
      stats_buffer: Onni.configuration.stats_buffer,
      stats_scale_sampled_hits: Onni.configuration.stats_scale_sampled_hits
    }
    example.run
  ensure
    previous.each { |key, value| Onni.configuration.public_send("#{key}=", value) }
    Onni.reset_request!
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
    Onni.configuration.stats_scale_sampled_hits = true
    Onni.configuration.stats_buffer = true
    Onni.reset_request!
  end

  it "coalesces repeated hits until flush" do
    expect(Onni.adapter).not_to receive(:record_stat)
    Onni::Stats.record("demo", shown: true)
    Onni::Stats.record("demo", shown: true)
    Onni::Stats.record("demo", shown: false)

    expect(Onni.adapter).to receive(:record_stats_batch).once.and_call_original
    expect(described_class.flush!).to eq(1)
    expect(Onni::Stats.for("demo").sum { |bucket| bucket["shown_count"] }).to eq(2)
    expect(Onni::Stats.for("demo").sum { |bucket| bucket["skip_count"] }).to eq(1)
  end

  it "flushes through reset_request! when buffering is show" do
    Onni::Stats.record("demo", shown: true)
    Onni.reset_request!
    expect(Onni::Stats.for("demo").sum { |bucket| bucket["shown_count"] }).to eq(1)
  end

  it "preserves summed weights when an adapter only supports individual writes" do
    Onni.adapter.singleton_class.undef_method(:record_stats_batch)
    maximum = Onni::Stats::Sampler::MAX_WEIGHT
    [maximum, maximum, 7].each do |weight|
      described_class.add("demo", shown: true, weight: weight)
      described_class.add("demo", shown: false, weight: weight)
    end

    expect(described_class.flush!).to eq(1)
    row = Onni::Stats.for("demo").fetch(0)
    expect(row).to include("shown_count" => maximum * 2 + 7, "skip_count" => maximum * 2 + 7)
    expect(described_class.flush!).to eq(0)
  end
end
