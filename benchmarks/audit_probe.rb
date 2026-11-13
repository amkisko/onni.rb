# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(ENV.fetch("PRESSURE_SOURCE"), "lib"))
require "json"
require "tempfile"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/time"
require "active_support/testing/time_helpers"
require "onni"

module AuditProbe
  extend ActiveSupport::Testing::TimeHelpers
  module_function

  def prepare(probe)
    Onni.configuration.stats_enabled = false
    Onni.adapter = Onni::Adapters::Memory.new
    case probe
    when "import", "import_standard", "import_indexed"
      rows = [
        {feature_key: "new_checkout", key: "powered", value: true},
        {feature_key: "new_checkout", key: "powered", value: (probe == "import") ? false : "false"},
        {feature_key: "search_v2", key: "percentage_of_actors", value: (probe == "import") ? "0x32" : "50"}
      ]
      if probe == "import_indexed"
        row_class = Struct.new(:feature_key, :key, :value)
        rows = rows.map { |row| row_class.new(**row) }
      end
      source = Onni::Migrator::Snapshot.new(feature_keys: %w[new_checkout search_v2], gates: rows)
      -> { Onni.migrate!(source) }
    when "fallback_small", "fallback_large"
      Onni.adapter.singleton_class.undef_method(:record_stats_batch)
      weight = (probe == "fallback_small") ? 1 : Onni::Stats::Sampler::MAX_WEIGHT + 7
      -> {
        Onni::Stats::Buffer.add(:new_checkout, shown: true, weight: weight)
        Onni::Stats::Buffer.add(:new_checkout, shown: false, weight: weight)
        Onni.flush_stats!
      }
    when "history"
      24.times do |hour|
        travel_to(Time.utc(2026, 1, 2) - hour.hours) do
          100.times { |index| Onni.adapter.record_stat("feature_#{index}", shown: true) }
        end
      end
      -> { Onni::Stats.for("feature_0", from: Time.utc(2026, 1, 1), to: Time.utc(2026, 1, 3)) }
    else raise ArgumentError, "Unknown audit probe #{probe}"
    end
  end

  def contract(probe, evaluations)
    case probe
    when "import", "import_standard", "import_indexed"
      {"parked" => Onni.parked?(:new_checkout), "level" => Onni.level(:search_v2)}
    when "fallback_small", "fallback_large"
      row = Onni::Stats.for(:new_checkout).fetch(0)
      weight = (probe == "fallback_small") ? 1 : Onni::Stats::Sampler::MAX_WEIGHT + 7
      {"expected_per_side" => evaluations * weight,
       "shown_count" => row.fetch("shown_count"), "skip_count" => row.fetch("skip_count")}
    when "history"
      rows = Onni::Stats.for("feature_0", from: Time.utc(2026, 1, 1), to: Time.utc(2026, 1, 3))
      starts = rows.map { |row| row.fetch("period_start") }
      unsupported = Onni::Stats.for("feature_0", period: "day", from: Time.utc(2026, 1, 1), to: Time.utc(2026, 1, 3))
      {"rows" => rows.size, "chronological" => starts == starts.sort, "unsupported_period_rows" => unsupported.size}
    end
  end

  def run
    probe = ENV.fetch("PROBE")
    count = Integer(ENV.fetch("N", "10000"))
    Tempfile.create(["onni-audit", ".yml"]) do |file|
      file.write("new_checkout:\n  type: boolean\nsearch_v2:\n  type: percentage\n")
      file.flush
      Onni.configuration.features_path = file.path
      Onni::Registry.reload!
      call = prepare(probe)
      100.times { call.call }
      GC.start
      allocations = GC.stat(:total_allocated_objects)
      cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      count.times { call.call }
      metrics = {
        "wall_s" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
        "cpu_s" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu,
        "allocated_objects" => GC.stat(:total_allocated_objects) - allocations
      }
      metrics.merge(
        "contract" => contract(probe, count + 100),
        "store_bytes" => JSON.generate(stored_rows(probe)).bytesize,
        "source_bytes" => Dir[File.join(ENV.fetch("PRESSURE_SOURCE"), "{lib,app,sig}/**/*")]
          .select { |path| File.file?(path) }.sum { |path| File.size(path) }
      )
    end
  end

  def stored_rows(probe)
    case probe
    when "import", "import_standard", "import_indexed"
      %w[new_checkout search_v2].to_h { |key| [key, Onni.adapter.gates_for(key)] }
    when "history"
      100.times.to_h do |index|
        key = "feature_#{index}"
        [key, Onni::Stats.for(key, from: Time.utc(2026, 1, 1), to: Time.utc(2026, 1, 3))]
      end
    else Onni::Stats.for(:new_checkout)
    end
  end
end

puts JSON.generate(AuditProbe.run)
