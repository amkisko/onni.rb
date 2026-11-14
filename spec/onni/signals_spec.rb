# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Integer signal contract" do
  let(:definition) { {"everyone" => true, "signals" => {"exception" => {"threshold" => 3}, "hold" => {}}} }

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    allow(Onni.configuration).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(Onni::Registry).to receive(:config).and_return("new_checkout" => definition)
    Onni.reset_request!
  end

  after { Onni.reset_request! }

  it "parks at the exact threshold even with preloaded gates and emits a reason once" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("feature_operation.onni") { |event| events << event.payload.dup }
    Onni.ready!(:new_checkout)
    Onni.preload!(:new_checkout)
    expect(Onni.observe!(:new_checkout, :exception, 2)).to eq(2)
    expect(Onni.ready?(:new_checkout)).to be(true)
    expect(Onni.observe!(:new_checkout, :exception)).to eq(3)
    expect(Onni.parked?(:new_checkout)).to be(true)
    Onni.observe!(:new_checkout, :exception)
    parks = events.select { |event| event[:operation] == :park }
    expect(parks.map { |event| event[:reason] }).to eq(["signal:exception"])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "heals and resets without readying and retains levels across clear" do
    Onni.ready!(:new_checkout)
    Onni.observe!(:new_checkout, :exception, 3)
    expect(Onni.observe!(:new_checkout, :exception, -2)).to eq(1)
    expect(Onni.parked?(:new_checkout)).to be(true)
    Onni.clear!(:new_checkout)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(1)
    expect(Onni.pending?(:new_checkout)).to be(true)
    Onni.reset_signals!(:new_checkout, :exception)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
    expect(Onni.pending?(:new_checkout)).to be(true)
  end

  it "updates runtime policies without powering and can disable thresholds" do
    Onni.signals!(:new_checkout, exception: {threshold: nil})
    expect(Onni.pending?(:new_checkout)).to be(true)
    Onni.ready!(:new_checkout)
    Onni.observe!(:new_checkout, :exception, 100)
    expect(Onni.ready?(:new_checkout)).to be(true)
    Onni.signals!(:new_checkout, hold: {threshold: 2})
    Onni.observe!(:new_checkout, :hold, 2)
    expect(Onni.parked?(:new_checkout)).to be(true)
    Onni.reset_signals!(:new_checkout)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
    expect(Onni.signal_level(:new_checkout, :hold)).to eq(0)
  end

  it "rejects unknown names, undeclared signals, floats and overflow without changing power or levels" do
    expect { Onni.observe!(:missing, :exception) }.to raise_error(KeyError)
    expect { Onni.observe!(:new_checkout, :user_123) }.to raise_error(ArgumentError)
    expect { Onni.observe!(:new_checkout, :exception, 1.2) }.to raise_error(ArgumentError)
    expect { Onni.signals!(:new_checkout, hold: {threshold: 0}) }.to raise_error(ArgumentError)
    expect { Onni.signals!(:new_checkout, hold: {unexpected: true}) }.to raise_error(ArgumentError)
    Onni.observe!(:new_checkout, :hold, (2**63) - 1)
    expect { Onni.observe!(:new_checkout, :hold) }.to raise_error(ArgumentError)
    expect(Onni.signal_level(:new_checkout, :hold)).to eq((2**63) - 1)
    expect(Onni.pending?(:new_checkout)).to be(true)
  end

  it "rejects malformed policies and duplicate normalized keys without mutation" do
    expect { Onni.signals!(:new_checkout, hold: nil) }.to raise_error(ArgumentError)
    expect { Onni.signals!(:new_checkout, **{:hold => {threshold: 2}, "hold" => {threshold: 3}}) }.to raise_error(ArgumentError)
    expect(Onni.exist?(:new_checkout)).to be(false)
  end

  it "does not interpret a false signal name as reset-all" do
    Onni.observe!(:new_checkout, :exception, 2)
    expect { Onni.reset_signals!(:new_checkout, false) }.to raise_error(ArgumentError)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(2)
  end

  it "parks legacy ready power and preserves explicit parked power during policy updates" do
    Onni.adapter.replace_gates(:new_checkout, [{"key" => "boolean", "value" => "true"}])
    Onni.observe!(:new_checkout, :exception, 3)
    Onni.signals!(:new_checkout, hold: {threshold: 2})
    expect(Onni.parked?(:new_checkout)).to be(true)
    Onni.ready!(:new_checkout)
    Onni.observe!(:new_checkout, :hold)
    expect(Onni.ready?(:new_checkout)).to be(true)
  end

  it "bounds retained levels when catalogue signal names change" do
    31.times do |index|
      key = "signal_#{index}"
      definition["signals"] = {key => {}}
      Onni.observe!(:new_checkout, key)
    end
    definition["signals"] = {"next_signal" => {}}
    expect { Onni.observe!(:new_checkout, :next_signal) }.to raise_error(ArgumentError)
    Onni.reset_signals!(:new_checkout)
    expect(Onni.observe!(:new_checkout, :next_signal)).to eq(1)
  end

  it "does not sample or buffer signals when evaluation collection is off" do
    allow(Onni.configuration).to receive_messages(stats_enabled: false, stats_sample_rate: 0.0, stats_buffer: true)
    Onni.ready!(:new_checkout)
    expect(Onni.observe!(:new_checkout, :exception, 3)).to eq(3)
    expect(Onni.parked?(:new_checkout)).to be(true)
    expect(Onni::Stats.for(:new_checkout)).to eq([])
  end

  it "does not lose increments from concurrent writers" do
    # Exercise the same feature lock used by threshold, reset, ready and park.
    writers = Array.new(8) { Thread.new { 50.times { Onni.observe!(:new_checkout, :exception) } } }
    writers.each(&:value)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(400)
  end
end
