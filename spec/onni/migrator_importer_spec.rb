# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Migrator::Importer do
  let(:source) do
    Onni::Migrator::Snapshot.new(
      feature_keys: %w[demo skipped],
      gates: [
        {feature_key: "demo", key: "boolean", value: "true"},
        {feature_key: "demo", key: "actors", value: "User;1"},
        {feature_key: "demo", key: "expression", value: "true"},
        {feature_key: "skipped", key: "boolean", value: "true"}
      ]
    )
  end

  around do |example|
    previous_stats_enabled = Onni.configuration.stats_enabled
    example.run
  ensure
    Onni.configuration.stats_enabled = previous_stats_enabled
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    allow(Onni::Registry).to receive(:known?) { |name| name.to_s == "demo" }
    allow(Onni::Registry).to receive(:require_definition!) { |name|
      raise KeyError unless name.to_s == "demo"
    }
  end

  it "imports only known features and supported gates" do
    result = described_class.new(source).call
    expect(result).to eq(features: 1, gates: 2, skipped_gates: 1)
    expect(Onni.enabled?(:demo)).to be(true)
    gates = Onni.adapter.gates_for(:demo)
    expect(gates).to include({"key" => "boolean", "value" => "true"})
    expect(gates).to include({"key" => "actors", "value" => "User;1"})
    expect(gates).not_to include(hash_including("key" => "expression"))
  end

  it "imports variants gates" do
    variants_source = Onni::Migrator::Snapshot.new(
      feature_keys: %w[demo],
      gates: [
        {feature_key: "demo", key: "boolean", value: "true"},
        {feature_key: "demo", key: "variants", value: JSON.generate("control" => 50, "treatment" => 50)}
      ]
    )

    result = described_class.new(variants_source).call
    expect(result).to eq(features: 1, gates: 2, skipped_gates: 0)
    expect(Onni[:demo].variants).to eq("control" => 50, "treatment" => 50)
  end

  it "accepts string-keyed gate rows" do
    string_source = Onni::Migrator::Snapshot.new(
      feature_keys: %w[demo],
      gates: [{"feature_key" => "demo", "key" => "groups", "value" => "beta_testers"}]
    )

    result = described_class.new(string_source).call
    expect(result).to eq(features: 1, gates: 1, skipped_gates: 0)
    expect(Onni.adapter.gates_for(:demo)).to include(
      {"key" => "groups", "value" => "beta_testers"}
    )
  end

  it "is reachable via Onni.migrate!" do
    result = Onni.migrate!(source)
    expect(result).to eq(features: 1, gates: 2, skipped_gates: 1)
  end
end
