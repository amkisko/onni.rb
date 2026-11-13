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
    allow(Onni::Registry).to receive(:definition).and_return("type" => "boolean")
    allow(Onni::Registry).to receive(:known?) { |name| name.to_s == "demo" }
    allow(Onni::Registry).to receive(:require_definition!) { |name|
      raise KeyError unless name.to_s == "demo"
    }
  end

  it "imports only known features and supported gates" do
    result = described_class.new(source).call
    expect(result).to eq(features: 1, gates: 1, skipped_gates: 2)
    expect(Onni.visible?(:demo)).to be(true)
    gates = Onni.adapter.gates_for(:demo)
    expect(gates).to include({"key" => "powered", "value" => "true"})
    expect(gates).not_to include(hash_including("key" => "actors"))
    expect(gates).not_to include(hash_including("key" => "expression"))
  end

  it "imports variants gates" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "experiment")
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
    allow(Onni::Registry).to receive(:definition).and_return("type" => "group")
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
    expect(result).to eq(features: 1, gates: 1, skipped_gates: 2)
  end

  it "does not import a mixed legacy gate as an OR across types" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "percentage", "level" => 0)
    mixed = Onni::Migrator::Snapshot.new(feature_keys: ["demo"], gates: [
      {feature_key: "demo", key: "boolean", value: "true"},
      {feature_key: "demo", key: "percentage_of_actors", value: "0"},
      {feature_key: "demo", key: "groups", value: "beta_testers"}
    ])
    result = Onni.migrate!(mixed)
    expect(result).to include(gates: 2, skipped_gates: 1)
    expect(Onni.ready?(:demo)).to be(true)
    expect(Onni.visible?(:demo, Struct.new(:id).new(1), record_stats: false)).to be(false)
  end

  it "skips malformed imported variant weights instead of breaking evaluation" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "experiment")
    malformed = Onni::Migrator::Snapshot.new(feature_keys: ["demo"], gates: [
      {feature_key: "demo", key: "boolean", value: "true"},
      {feature_key: "demo", key: "variants", value: JSON.generate("control" => {"weight" => 100})}
    ])
    expect(Onni.migrate!(malformed)).to include(gates: 1, skipped_gates: 1)
    expect(Onni.visible?(:demo, record_stats: false)).to be(false)
  end

  it "imports boolean false from symbol-keyed rows as explicit parked power" do
    Onni.ready!(:demo)
    snapshot = Onni::Migrator::Snapshot.new(feature_keys: ["demo"], gates: [
      {feature_key: "demo", key: "boolean", value: false}
    ])

    expect(Onni.migrate!(snapshot)).to include(gates: 1, skipped_gates: 0)
    expect(Onni.parked?(:demo)).to be(true)
    expect(Onni.visible?(:demo, record_stats: false)).to be(false)
  end

  it "imports source rows that provide indexed fields without Hash methods" do
    row = Struct.new(:feature_key, :key, :value).new("demo", "boolean", "true")
    snapshot = Onni::Migrator::Snapshot.new(feature_keys: ["demo"], gates: [row])

    expect(Onni.migrate!(snapshot)).to include(gates: 1, skipped_gates: 0)
    expect(Onni.visible?(:demo, record_stats: false)).to be(true)
  end

  it "stores imported percentage levels with the same integer interpretation as validation" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "percentage")
    ["0x32", "1_0", "050", 25.9].each do |value|
      snapshot = Onni::Migrator::Snapshot.new(feature_keys: ["demo"], gates: [
        {feature_key: "demo", key: "percentage_of_actors", value: value}
      ])

      expect(Onni.migrate!(snapshot)).to include(gates: 1, skipped_gates: 0)
      expect(Onni.level(:demo)).to eq(Integer(value))
    end
  end
end
