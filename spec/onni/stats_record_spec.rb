# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Stats do
  around do |example|
    previous_rate = Onni.configuration.stats_sample_rate
    previous_scale = Onni.configuration.stats_scale_sampled_hits
    previous_enabled = Onni.configuration.stats_enabled
    previous_logger = Onni.configuration.logger
    example.run
  ensure
    Onni.configuration.stats_sample_rate = previous_rate
    Onni.configuration.stats_scale_sampled_hits = previous_scale
    Onni.configuration.stats_enabled = previous_enabled
    Onni.configuration.logger = previous_logger
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
    Onni.configuration.stats_scale_sampled_hits = true
  end

  it "stores a scaled hit weight when sampling keeps the event" do
    allow(Random).to receive(:rand).and_return(0.01)
    Onni.configuration.stats_sample_rate = 0.1

    described_class.record("demo", shown: true)

    expect(described_class.for("demo").sum { |bucket| bucket["shown_count"] }).to eq(10)
  end

  it "stores raw sample counts when scaling is disabled" do
    allow(Random).to receive(:rand).and_return(0.01)
    Onni.configuration.stats_sample_rate = 0.1
    Onni.configuration.stats_scale_sampled_hits = false

    described_class.record("demo", shown: true)

    expect(described_class.for("demo").sum { |bucket| bucket["shown_count"] }).to eq(1)
  end

  it "does not create buckets when stats are disabled" do
    Onni.configuration.stats_enabled = false
    described_class.record("demo", shown: true)
    expect(described_class.for("demo")).to eq([])
  end

  it "swallows adapter errors and reports them through the configured logger" do
    logger = instance_double(Logger, warn: true)
    Onni.configuration.logger = logger
    allow(Onni.adapter).to receive(:record_stat).and_raise(RuntimeError, "boom")

    expect { described_class.record("demo", shown: true) }.not_to raise_error
    expect(logger).to have_received(:warn).with(/Onni stats failed/)
  end
end
