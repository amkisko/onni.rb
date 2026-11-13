# frozen_string_literal: true

require_relative "load"

module Onni
  module Bench
    module PressureProbe
      module_function

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def measure
        GC.start
        allocations = GC.stat(:total_allocated_objects)
        cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
        started = clock
        yield
        {
          "wall_s" => clock - started,
          "cpu_s" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu,
          "allocated_objects" => GC.stat(:total_allocated_objects) - allocations
        }
      end

      def calibrate
        stages = {}
        metrics = measure do
          {"lookup" => 0.001, "evaluate" => 0.003, "record" => 0.006}.each do |name, duration|
            samples = Array.new(9) do
              started = clock
              sleep duration
              clock - started
            end
            stages[name] = samples.sort.fetch(8)
            raise "Clock did not measure #{name}" unless stages[name] >= duration * 0.9
          end
          @calibration_memory = "x" * (32 * 1024 * 1024)
          @calibration_objects = Array.new(20_000) { "allocation".dup }
        end
        ordered = stages.values.each_cons(2).all? { |left, right| left < right }
        raise "Stage/aggregate calibration failed" unless ordered && stages.values.sum < metrics.fetch("wall_s")
        raise "Allocation calibration failed" unless metrics.fetch("allocated_objects") >= 20_000

        metrics.merge("stage_p95_s" => stages, "calibrated" => true)
      end

      def operation(probe, actor)
        case probe
        when "all" then -> { Load.run_all_features_batch!(1, actors: [actor]) }
        when "global", "cache" then -> { Onni.visible?(:flag_boolean, record_stats: false) }
        when "parked", "pending" then -> { Onni.visible?(:flag_group, actor) }
        when "conditions" then -> { Onni.visible?(:flag_boolean, actor, record_stats: false) }
        when "group", "legacy_group" then -> { Onni.visible?(:flag_group, actor, record_stats: false) }
        when "legacy_power" then -> { Onni.visible?(:flag_boolean, actor, record_stats: false) }
        when "variant" then -> { Onni.variant(:flag_variant, actor, record_stats: false) }
        when "ignored", "sampler" then -> { Onni::Stats::Sampler.decide(name: :flag_boolean, shown: true) }
        when "stats_disabled" then -> { Onni::Stats.record(:flag_boolean, shown: true) }
        when "buffer" then -> { Onni::Stats::Buffer.add(:flag_boolean, shown: true, weight: 1) }
        when "memory_write" then -> { Onni.adapter.record_stat(:flag_boolean, shown: true) }
        when "gate_write" then -> { Onni.ready!(:flag_boolean) }
        else raise ArgumentError, "Unknown pressure probe #{probe}"
        end
      end

      def prepare(probe)
        Load.prepare_features!
        Onni.park!(:flag_group) if probe == "parked"
        Onni.clear!(:flag_group) if probe == "pending"
        Onni.configuration.cache = ActiveSupport::Cache::MemoryStore.new if probe == "cache"
        Onni.configuration.stats_enabled = %w[all parked pending ignored sampler buffer memory_write].include?(probe)
        Onni.configuration.stats_sample_rate = 1.0 if %w[sampler buffer memory_write].include?(probe)
        Onni.configuration.stats_sample_rate = 0.0 if probe == "ignored"
        Onni.configuration.stats_ignore = Array.new(100) { |index| "ignored_#{index}" } if probe == "ignored"
        if probe == "legacy_group"
          names = %w[legacy_one legacy_two legacy_three legacy_four staff]
          Onni.adapter.replace_gates(:flag_group, names.map { |name| {key: "groups", value: name} })
        end
        Onni.adapter.replace_gates(:flag_boolean, [{key: "boolean", value: "true"}]) if probe == "legacy_power"
        Kernel.srand(42)
      end

      def run(probe, count)
        Load.with_registry! do
          prepare(probe)
          actor = Load.actor_class.new(0, beta_tester: true)
          call = operation(probe, actor)
          1_000.times { call.call }
          metrics = measure { count.times { call.call } }
          if %w[parked pending].include?(probe)
            raise "Hard-off contract failed" if Onni.visible?(:flag_group, actor)
            raise "Hard-off stats contract failed" unless Onni::Stats.for(:flag_group).empty?
          end
          raise "Global contract failed" unless Onni.visible?(:flag_boolean, actor, record_stats: false)
          raise "Percentage contract failed" unless Onni.visible?(:flag_percentage, actor, record_stats: false)
          raise "Variant contract failed" unless Onni.variant(:flag_variant, actor, record_stats: false)
          buckets = Onni::Stats.for(:flag_boolean)
          if %w[buffer memory_write].include?(probe)
            Onni.flush_stats! if probe == "buffer"
            buckets = Onni::Stats.for(:flag_boolean)
            raise "Counter contract failed" unless buckets.sum { |row| row.fetch("shown_count") } == count + 1_000
          end
          stored = Onni.adapter.feature_keys.flat_map { |name| Onni::Stats.for(name) }
          cache_bytes = Onni.configuration.cache&.instance_variable_get(:@cache_size)
          raise "Cache size meter unavailable" if probe == "cache" && cache_bytes.nil?
          metrics.merge(
            "stats_rows" => stored.size,
            "store_bytes" => JSON.generate(stored).bytesize,
            "cache_accounted_bytes" => cache_bytes || 0,
            "source_bytes" => Dir[File.join(ENV.fetch("PRESSURE_SOURCE"), "{lib,app,sig}/**/*")].select { |path| File.file?(path) }.sum { |path| File.size(path) },
            "stage_batch_p95_s" => stage_latencies(actor)
          )
        end
      end

      def stage_latencies(actor)
        calls = {
          "boolean" => -> { Onni.visible?(:flag_boolean, record_stats: false) },
          "actor" => -> { Onni.visible?(:flag_actor, actor, record_stats: false) },
          "percentage" => -> { Onni.visible?(:flag_percentage, actor, record_stats: false) },
          "group" => -> { Onni.visible?(:flag_group, actor, record_stats: false) },
          "variant" => -> { Onni.variant(:flag_variant, actor, record_stats: false) },
          "conditions" => -> { Onni.visible?(:flag_conditions, actor, record_stats: false) },
          "stats" => -> { Onni::Stats.record(:flag_stats, shown: true) }
        }
        calls.transform_values do |call|
          Array.new(20) do
            started = clock
            100.times { call.call }
            clock - started
          end.sort.fetch(18)
        end
      end
    end
  end
end

probe = ENV.fetch("PROBE", "all")
result = if probe == "calibrate"
  Onni::Bench::PressureProbe.calibrate
else
  Onni::Bench::PressureProbe.run(probe, Integer(ENV.fetch("N", "100000")))
end
puts JSON.generate(result)
