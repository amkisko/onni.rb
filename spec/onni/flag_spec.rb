# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Flag do
  around do |example|
    previous_stats_enabled = Onni.configuration.stats_enabled
    example.run
  ensure
    Onni.configuration.stats_enabled = previous_stats_enabled
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    allow(Onni::Registry).to receive(:require_definition!)
    allow(Onni::Registry).to receive_messages(
      known?: true,
      definition: {
        "description" => "Demo",
        "expires_at" => "2099-01-01",
        "variants" => {"control" => 40, "treatment" => 60}
      }
    )
  end

  it "reads description and expiry from the YAML definition" do
    flag = described_class.new(:demo)
    expect(flag.description).to eq("Demo")
    expect(flag.expires_at).to eq("2099-01-01")
    expect(flag.exist?).to be(true)
  end

  it "prefers YAML variants over gate variants" do
    Onni.enable(:demo)
    Onni.set_variants(:demo, {control: 10, treatment: 90})
    expect(described_class.new(:demo).variants).to eq("control" => 40, "treatment" => 60)
  end

  it "falls back to gate variants when YAML has none" do
    allow(Onni::Registry).to receive(:definition).and_return(
      "description" => "Demo",
      "expires_at" => "2099-01-01"
    )
    Onni.enable(:demo)
    Onni.set_variants(:demo, {control: 25, treatment: 75})
    expect(described_class.new(:demo).variants).to eq("control" => 25, "treatment" => 75)
  end

  it "treats invalid gate variant JSON as empty" do
    allow(Onni::Registry).to receive(:definition).and_return(
      "description" => "Demo",
      "expires_at" => "2099-01-01"
    )
    Onni.adapter.replace_gates("demo", [{"key" => "variants", "value" => "{not-json"}])
    expect(described_class.new(:demo).variants).to eq({})
  end
end
