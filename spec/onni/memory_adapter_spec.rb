# frozen_string_literal: true

require "spec_helper"
require "active_support/testing/time_helpers"

RSpec.describe Onni::Adapters::Memory do
  include ActiveSupport::Testing::TimeHelpers

  subject(:adapter) { described_class.new }

  it "clears features, gates, and stats" do
    adapter.add("demo")
    adapter.add_gate("demo", "boolean", "true")
    adapter.record_stat("demo", shown: true)

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

  it "keeps arbitrary feature keys distinct in stat buckets" do
    adapter.record_stat("new_checkout|control", shown: true)
    adapter.record_stat("new_checkout", shown: false)
    expect(adapter.stats_for("new_checkout|control").sum { |row| row.fetch("shown_count") }).to eq(1)
    expect(adapter.stats_for("new_checkout").sum { |row| row.fetch("skip_count") }).to eq(1)
  end

  it "owns the stat key instead of retaining a mutable caller string" do
    key = +"new_checkout"
    adapter.record_stat(key, shown: true)
    key.replace("search_v2")
    expect(adapter.stats_for("new_checkout").sum { |row| row.fetch("shown_count") }).to eq(1)
    expect(adapter.stats_for("search_v2")).to eq([])
  end

  it "does not freeze a string returned by a custom feature key" do
    key_class = Struct.new(:value) do
      def to_s
        value
      end
    end
    key = key_class.new(+"new_checkout")
    adapter.record_stat(key, shown: true)
    key.value.replace("search_v2")
    expect(adapter.stats_for("new_checkout").sum { |row| row.fetch("shown_count") }).to eq(1)
  end

  it "keeps gate readers independent of stored data and the caller's input" do
    value = +"true"
    adapter.add_gate("demo", "boolean", value)
    value.replace("false")
    read = adapter.gates_for("demo")
    read.first["value"].replace("changed")
    expect(adapter.gates_for("demo")).to eq([{"key" => "boolean", "value" => "true"}])
  end

  it "provides immutable evaluation snapshots that survive later gate writes" do
    adapter.add_gate("demo", "boolean", "true")
    snapshot = adapter.gates_snapshot_for("demo")
    expect { snapshot.first["value"].replace("changed") }.to raise_error(FrozenError)
    adapter.add_gate("demo", "groups", "beta_testers")
    adapter.remove_gate("demo", "boolean")
    expect(snapshot).to eq([{"key" => "boolean", "value" => "true"}])
    expect(adapter.gates_snapshot_for("demo")).to eq([{"key" => "groups", "value" => "beta_testers"}])
  end

  it "does not publish partial gate edits when an update fails" do
    adapter.add_gate("demo", "boolean", "true")
    expect {
      adapter.update_gates("demo") do |gates|
        gates.first["value"].replace("false")
        raise "aborted"
      end
    }.to raise_error(RuntimeError, "aborted")
    expect(adapter.gates_for("demo")).to eq([{"key" => "boolean", "value" => "true"}])
  end

  it "returns hourly history in chronological order regardless of insertion order" do
    [Time.utc(2026, 1, 2, 12), Time.utc(2026, 1, 2, 10), Time.utc(2026, 1, 2, 11)].each do |time|
      travel_to(time) { adapter.record_stat("demo", shown: true) }
    end

    rows = adapter.stats_for("demo", from: Time.utc(2026, 1, 2), to: Time.utc(2026, 1, 3))
    expect(rows.map { |row| row.fetch("period_start").hour }).to eq([10, 11, 12])
    expect(rows.sum { |row| row.fetch("shown_count") }).to eq(3)
  end

  it "does not relabel hourly buckets as another period" do
    adapter.record_stat("demo", shown: true)

    expect(adapter.stats_for("demo", period: "day")).to eq([])
    expect(adapter.stats_for("demo").sum { |row| row.fetch("shown_count") }).to eq(1)
  end
end
