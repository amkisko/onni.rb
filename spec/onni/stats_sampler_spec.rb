# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Stats::Sampler do
  around do |example|
    previous = {
      stats_enabled: Onni.configuration.stats_enabled,
      stats_sample_rate: Onni.configuration.stats_sample_rate,
      stats_sampler: Onni.configuration.stats_sampler,
      stats_ignore: Onni.configuration.stats_ignore,
      stats_scale_sampled_hits: Onni.configuration.stats_scale_sampled_hits
    }
    example.run
  ensure
    previous.each { |key, value| Onni.configuration.public_send("#{key}=", value) }
  end

  before do
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
    Onni.configuration.stats_sampler = nil
    Onni.configuration.stats_ignore = []
    Onni.configuration.stats_scale_sampled_hits = true
  end

  it "skips when stats are disabled" do
    Onni.configuration.stats_enabled = false
    expect(described_class.decide(name: "demo", shown: true)).to eq(:skip)
  end

  it "skips ignored feature keys" do
    Onni.configuration.stats_ignore = %w[demo]
    expect(described_class.decide(name: :demo, shown: true)).to eq(:skip)
  end

  it "records with weight 1 when sample rate is 1.0 without drawing Random" do
    expect(Random).not_to receive(:rand)
    expect(described_class.decide(name: "demo", shown: true)).to eq(record: true, weight: 1)
  end

  it "clamps sample rates outside 0.0..1.0" do
    expect(described_class.coerce_rate(1.5)).to eq(1.0)
    expect(described_class.coerce_rate(-0.2)).to eq(0.0)
  end

  it "coerces boolean and nil sampler rates" do
    expect(described_class.coerce_rate(true)).to eq(1.0)
    expect(described_class.coerce_rate(false)).to eq(0.0)
    expect(described_class.coerce_rate(nil)).to eq(0.0)
  end

  it "uses stats_sampler rate when present" do
    Onni.configuration.stats_sampler = ->(context) {
      (context[:name] == "busy") ? 0.0 : 1.0
    }
    expect(described_class.decide(name: "busy", shown: true)).to eq(:skip)
    expect(described_class.decide(name: "quiet", shown: true)).to eq(record: true, weight: 1)
  end

  it "provides the shown outcome without a power-state payload" do
    received = nil
    Onni.configuration.stats_sampler = ->(context) {
      received = context
      1.0
    }
    described_class.decide(name: :new_checkout, shown: false)
    expect(received).to eq(name: "new_checkout", shown: false)
  end

  it "falls back to the configured rate and still coerces custom rates" do
    allow(Random).to receive(:rand).and_return(0.01)
    Onni.configuration.stats_sample_rate = 0.5
    Onni.configuration.stats_sampler = ->(_context) {}
    expect(described_class.decide(name: "demo", shown: true)).to eq(record: true, weight: 2)
    Onni.configuration.stats_sampler = ->(_context) { "0.25" }
    expect(described_class.decide(name: "demo", shown: true)).to eq(record: true, weight: 4)
  end

  it "scales weight as the inverse of the sample rate when show" do
    allow(Random).to receive(:rand).and_return(0.05)
    Onni.configuration.stats_sample_rate = 0.1
    expect(described_class.decide(name: "demo", shown: true)).to eq(record: true, weight: 10)
  end

  it "keeps weight 1 when scaling is disabled" do
    allow(Random).to receive(:rand).and_return(0.05)
    Onni.configuration.stats_sample_rate = 0.1
    Onni.configuration.stats_scale_sampled_hits = false
    expect(described_class.decide(name: "demo", shown: true)).to eq(record: true, weight: 1)
  end

  it "skips when the random draw falls outside the rate" do
    allow(Random).to receive(:rand).and_return(0.9)
    Onni.configuration.stats_sample_rate = 0.1
    expect(described_class.decide(name: "demo", shown: true)).to eq(:skip)
  end
end
