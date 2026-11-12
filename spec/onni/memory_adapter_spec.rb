# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Adapters::Memory do
  subject(:adapter) { described_class.new }

  it "clears features, gates, and stats" do
    adapter.add("demo")
    adapter.add_gate("demo", "boolean", "true")
    adapter.record_stat("demo", enabled: true)

    adapter.clear!

    expect(adapter.exist?("demo")).to be(false)
    expect(adapter.gates_for("demo")).to eq([])
    expect(adapter.stats_for("demo")).to eq([])
  end

  it "replaces gates including symbol-keyed entries" do
    adapter.replace_gates("demo", [{key: "boolean", value: true}, {"key" => "groups", "value" => "staff"}])

    expect(adapter.gates_for("demo")).to contain_exactly(
      {"key" => "boolean", "value" => "true"},
      {"key" => "groups", "value" => "staff"}
    )
  end
end
