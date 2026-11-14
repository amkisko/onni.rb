# frozen_string_literal: true

require "rails_helper"
require_relative "../support/agent_access"

RSpec.describe "Onni GraphQL signals", type: :request do
  include_context "with device-authorized Onni"

  let(:observe) do
    'mutation($delta: OnniSignedInteger!) { onni_observe(name: "demo", signal: "exception", delta: $delta) { power signals { key level threshold } } }'
  end

  it "applies thresholds, parks atomically, and resets without readying" do
    graphql('mutation { onni_set_signal_threshold(name: "demo", signal: "exception", threshold: "2") { power } }')
    expect(Onni.pending?(:demo)).to be(true)
    graphql('mutation { onni_ready(name: "demo") { power } }')
    graphql(observe, variables: {delta: 1})
    data = graphql(observe, variables: {delta: 1})
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "onni_observe", "power")).to eq("PARKED")
    expect(data.dig("data", "onni_observe", "signals")).to include("key" => "exception", "level" => "2", "threshold" => "2")
    data = graphql('mutation { onni_reset_signals(name: "demo", signal: "exception") { power signals { level } } }')
    expect(data["errors"]).to be_nil
    expect(Onni.signal_level(:demo, :exception)).to eq(0)
    expect(Onni.parked?(:demo)).to be(true)
    expect(Onni::Stats.for(:demo)).to eq([])
  end

  it "preserves exact 64-bit integers and supports negative healing" do
    maximum = (2**63) - 1
    data = graphql(observe, variables: {delta: maximum.to_s})
    expect(data["errors"]).to be_nil
    expect(Onni.signal_level(:demo, :exception)).to eq(maximum)
    data = graphql(observe, variables: {delta: "-1"})
    expect(data["errors"]).to be_nil
    expect(Onni.signal_level(:demo, :exception)).to eq(maximum - 1)
  end

  it "rejects float, overflow and non-decimal string deltas before mutation" do
    [1.5, ((2**63) + 1).to_s, "1_0", "1.0"].each do |delta|
      data = graphql(observe, variables: {delta: delta})
      expect(data["errors"]).to be_present
      expect(Onni.signal_level(:demo, :exception)).to eq(0)
    end
  end

  it "requires an explicit threshold, permits null to disable it, and retains levels across clear" do
    Onni.signals!(:demo, exception: {threshold: 1})
    data = graphql('mutation { onni_set_signal_threshold(name: "demo", signal: "exception") { name } }')
    expect(data["errors"]).to be_present
    data = graphql('mutation { onni_set_signal_threshold(name: "demo", signal: "exception", threshold: null) { name } }')
    expect(data["errors"]).to be_nil
    Onni.ready!(:demo)
    graphql(observe, variables: {delta: 3})
    expect(Onni.ready?(:demo)).to be(true)
    data = graphql('mutation { onni_clear(name: "demo") { power signals { level } } }')
    expect(data["errors"]).to be_nil
    expect(Onni.pending?(:demo)).to be(true)
    expect(Onni.signal_level(:demo, :exception)).to eq(3)
  end
end
