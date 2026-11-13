# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Evaluation statistics policy" do
  let(:definition) { {"everyone" => true, "type" => "experiment", "variants" => {"treatment" => 100}} }
  let(:actor) { Struct.new(:id).new(7) }

  around do |example|
    previous = %i[stats_enabled stats_sample_rate stats_sampler stats_ignore stats_buffer cache adapter].to_h do |key|
      [key, Onni.configuration.public_send(key)]
    end
    example.run
  ensure
    previous.each { |key, value| Onni.configuration.public_send("#{key}=", value) }
    Onni.reset_request!
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
    Onni.configuration.stats_sampler = nil
    Onni.configuration.stats_ignore = []
    Onni.configuration.stats_buffer = false
    Onni.configuration.cache = nil
    Onni.reset_request!
    allow(Onni::Registry).to receive(:config).and_return("new_checkout" => definition)
  end

  def totals
    rows = Onni::Stats.for(:new_checkout)
    %w[shown_count skip_count].map { |key| rows.sum { |row| row.fetch(key) } }
  end

  it "records known pending, parked, ready, expired, and audience outcomes by default" do
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
    Onni.ready!(:new_checkout)
    expect(Onni.visible?(:new_checkout, actor)).to be(true)
    Onni.park!(:new_checkout)
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
    Onni.ready!(:new_checkout)
    definition["expires_at"] = "2000-01-01"
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
    definition.delete("expires_at")
    Onni.filters!(:new_checkout, actors: [])
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
    expect(totals).to eq([1, 4])
    expect(Onni.visible?(:missing, actor)).to be(false)
    expect(Onni::Stats.for(:missing)).to eq([])
  end

  it "counts unassigned known variant calls without changing visibility or power" do
    expect(Onni.variant(:new_checkout, actor)).to be_nil
    Onni.ready!(:new_checkout)
    expect(Onni.variant(:new_checkout, nil)).to be_nil
    expect(Onni.variant(:new_checkout, actor)).to eq(:treatment)
    Onni.variants!(:new_checkout, {})
    expect(Onni.variant(:new_checkout, actor)).to be_nil
    Onni.park!(:new_checkout)
    expect(Onni.variant(:new_checkout, actor)).to be_nil
    expect(totals).to eq([1, 4])
  end

  it "checks collection controls across all power states and both evaluation APIs" do
    %i[pending ready parked].product([nil, false, true], [nil, false, true], [nil, false, true], [false, true], [0.0, 1.0]).each do |power, inline, yaml, runtime, global, rate|
      Onni.adapter.clear!
      definition["stats"] = yaml.nil? ? {} : {"enabled" => yaml}
      Onni.configuration.stats_enabled = global
      Onni.configuration.stats_sample_rate = rate
      Onni.ready!(:new_checkout) if power == :ready
      Onni.park!(:new_checkout) if power == :parked
      Onni.stats!(:new_checkout, enabled: runtime) unless runtime.nil?
      visible = Onni.visible?(:new_checkout, actor, record_stats: inline)
      assigned = Onni.variant(:new_checkout, actor, record_stats: inline)
      choice = [inline, runtime, yaml, true].find { |value| !value.nil? }
      recorded = global && choice && rate.positive?
      counts = (power == :ready) ? [2, 0] : [0, 2]
      expected = recorded ? counts : [0, 0]
      expect([visible, assigned, totals]).to eq([power == :ready, (power == :ready) ? :treatment : nil, expected]),
        -> { [power, inline, yaml, runtime, global, rate].inspect }
    end
  end

  it "uses feature rates, preserves sampler fallback, and retains global vetoes" do
    definition["stats"] = {"sample_rate" => 0.25}
    Onni.configuration.stats_sample_rate = 0.1
    Onni.configuration.stats_sampler = ->(_context) {}
    allow(Random).to receive(:rand).and_return(0.01)
    Onni.visible?(:new_checkout, actor)
    expect(totals).to eq([0, 4])
    Onni.stats!(:new_checkout, sample_rate: 0.5)
    Onni.visible?(:new_checkout, actor)
    expect(totals).to eq([0, 6])
    Onni.configuration.stats_ignore = [:new_checkout]
    Onni.visible?(:new_checkout, actor, record_stats: true)
    expect(totals).to eq([0, 6])
    Onni.configuration.stats_ignore = []
    Onni.stats!(:new_checkout, sample_rate: nil)
    Onni.visible?(:new_checkout, actor)
    expect(totals).to eq([0, 10])
  end

  it "preserves feature settings through park and restores YAML settings after clear" do
    definition["stats"] = {"enabled" => false, "sample_rate" => 0.25}
    Onni.stats!(:new_checkout, enabled: true, sample_rate: 1.0)
    expect(Onni.pending?(:new_checkout)).to be(true)
    Onni.park!(:new_checkout)
    expect(Onni[:new_checkout].stats_settings).to eq("enabled" => true, "sample_rate" => 1.0)
    Onni.clear!(:new_checkout)
    expect(Onni[:new_checkout].stats_settings).to eq("enabled" => false, "sample_rate" => 0.25)
  end

  it "rejects malformed settings and inline options before changing state" do
    Onni.stats!(:new_checkout, enabled: false)
    [{enabled: "false"}, {sample_rate: -0.1}, {sample_rate: 1.1},
      {sample_rate: Float::NAN}, {unknown: true}].each do |invalid|
      expect { Onni.stats!(:new_checkout, **invalid) }.to raise_error(ArgumentError)
    end
    expect(Onni[:new_checkout].stats_settings["enabled"]).to be(false)
    expect { Onni.visible?(:new_checkout, record_stats: "false") }.to raise_error(ArgumentError)
    expect { Onni.variant(:new_checkout, actor, record_stats: 1) }.to raise_error(ArgumentError)
    expect(totals).to eq([0, 0])
  end

  it "preserves gates and counters when ordinary application settings change" do
    Onni.configuration.adapter = :memory
    Onni.ready!(:new_checkout)
    Onni.visible?(:new_checkout, actor)
    Onni.configure { |config| config.stats_enabled = false }
    expect(Onni.visible?(:new_checkout, actor)).to be(true)
    Onni.configure { |config| config.stats_enabled = true }
    Onni.visible?(:new_checkout, actor)
    expect(totals).to eq([2, 0])
  end

  it "flushes already accepted counts after buffering is disabled at runtime" do
    Onni.configuration.stats_buffer = true
    Onni.visible?(:new_checkout, actor)
    Onni.configuration.stats_buffer = false
    Onni.reset_request!
    expect(totals).to eq([0, 1])
  end
end
