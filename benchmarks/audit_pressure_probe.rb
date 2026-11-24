# frozen_string_literal: true

require "json"
require "tmpdir"
require "active_support/notifications"
require "active_support/core_ext/numeric/time"

root = ENV.fetch("PRESSURE_SOURCE")
$LOAD_PATH.unshift(File.join(root, "lib"))
require "onni"

module AuditPressureProbe
  CUTOFF = Time.utc(2026, 1, 2)
  START = CUTOFF - 86_400
  NOW = Time.utc(2026, 1, 3)
  FEATURE = "new_checkout"

  module_function

  def run(probe, size, directory)
    Onni.configuration.features_path = nil
    Onni.configuration.stats_enabled = false
    database = File.join(directory, "stats.sqlite3")
    setup_database(database) if probe.start_with?("database_") || probe == "catalogue"
    metrics = workload(probe, size)
    files = Dir["#{database}*"]
    stats = Onni.adapter.stats_overview
    metrics.merge("store_rows" => stats.fetch(:bucket_count), "store_bytes" => files.empty? ? JSON.generate(stats).bytesize : files.sum { |path| File.size(path) },
      "source_bytes" => Dir[File.join(ENV.fetch("PRESSURE_SOURCE"), "{lib,app,sig}/**/*")].sum { |path| File.file?(path) ? File.size(path) : 0 })
  end

  def setup_database(path)
    require "active_record"
    require "onni/active_record"
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: path)
    ActiveRecord::Schema.verbose = false
    load File.expand_path("../spec/dummy/db/onni_schema.rb", __dir__)
    Onni.adapter = Onni::Adapters::ActiveRecord.new
  end

  def workload(probe, size)
    adapter = Onni.adapter
    case probe
    when "memory_purge", "memory_history", "memory_overview"
      memory_statistics(adapter, probe, size)
    when "database_gate", "database_preload", "catalogue"
      database_gates(adapter, probe, size)
    when "database_history"
      rows = Array.new(size) { |index| {feature_key: FEATURE, period_start: START + index * 3600, shown_count: 1} }
      Onni::StatBucket.insert_all!(rows)
      repeat(12) { adapter.stats_for(FEATURE, from: START, to: START + size * 3600).size == size }
    when "database_write", "memory_write"
      metrics = repeat(size) { adapter.record_stat(FEATURE, shown: true) }
      raise "Counter diverged" unless adapter.stats_for(FEATURE).sum { |row| row.fetch("shown_count") } == size

      metrics
    when "pending"
      declare(FEATURE)
      repeat(size) { Onni.visible?(FEATURE) == false }
    when "legacy_snapshot"
      gates = Array.new(80) { |index| {"key" => "actors", "value" => "actor_#{index}"} }
      repeat(size) { Onni::GateSnapshot.wrap(gates).filters.fetch("actors").size == 80 }
    else
      raise "Unknown workload #{probe}"
    end
  end

  def memory_statistics(adapter, probe, size)
    require "active_support/testing/time_helpers"
    clock = Object.new.extend(ActiveSupport::Testing::TimeHelpers)
    clock.travel_to(NOW) { adapter.record_stat(FEATURE, shown: true) }
    if probe == "memory_history"
      size.times { |index| clock.travel_to(START - index * 3600) { adapter.record_stat(FEATURE, shown: false) } }
    else
      clock.travel_to(START) do
        size.times { |index| adapter.record_stat("checkout_#{index}", shown: true) }
      end
    end
    case probe
    when "memory_purge"
      metrics, result = measure { Onni.purge_stats!(older_than: CUTOFF, batch_size: 100) }
      raise "Purge removed the wrong rows" unless result[:deleted] == size && adapter.stats_overview[:bucket_count] == 1

      metrics
    when "memory_history"
      repeat(100) { adapter.stats_for(FEATURE, from: CUTOFF, to: NOW).first.fetch("shown_count") == 1 }
    when "memory_overview"
      repeat(100) { adapter.stats_overview == {bucket_count: size + 1, oldest_period_start: START} }
    end
  end

  def database_gates(adapter, probe, size)
    keys = Array.new(size) { |index| "checkout_#{index}" }
    Onni::Gate.insert_all!(keys.flat_map do |key|
      [{feature_key: key, key: "powered", value: "true"}, {feature_key: key, key: "percentage_of_actors", value: "25"}]
    end)
    queries = 0
    subscriber = ->(_name, _start, _finish, _id, payload) { queries += 1 if payload[:name] != "SCHEMA" }
    case probe
    when "database_gate"
      keys.each { |key| declare(key) }
      round = -> { keys.all? { |key| Onni.ready?(key) } }
    when "database_preload"
      round = -> { Onni.preload!(keys) == size && Onni.reset_request! }
    when "catalogue"
      keys.each { |key| declare(key) }
      round = -> { JSON.parse(Onni.export_catalogue(format: :json, runtime: true)).size == size }
    end

    round.call
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { repeat(3, &round) }
      .merge("queries" => queries)
  end

  def declare(key)
    Onni.define!(key, everyone: true, description: "Checkout rollout", expires_at: "2099-01-01")
  end

  def repeat(count)
    measure do
      count.times { raise "Workload output differed" unless yield }
    end.first
  end

  def measure
    GC.start
    allocations = GC.stat(:total_allocated_objects)
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    [{"wall_s" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall,
      "cpu_s" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu,
      "allocated_objects" => GC.stat(:total_allocated_objects) - allocations}, result]
  end
end

Dir.mktmpdir("onni-audit-pressure") do |directory|
  puts JSON.generate(AuditPressureProbe.run(ENV.fetch("PROBE"), Integer(ENV.fetch("N")), directory))
end
