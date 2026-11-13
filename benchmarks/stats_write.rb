#!/usr/bin/env ruby
# frozen_string_literal: true

# Pressure / load bench for ActiveRecord hit-stat upserts (lock contention).
#
# Usage:
#   SCENARIO=calibrate bundle exec ruby benchmarks/stats_write.rb
#   SCENARIO=ladder bundle exec ruby benchmarks/stats_write.rb
#   SCENARIO=matrix bundle exec ruby benchmarks/stats_write.rb
#   SCENARIO=observe MODE=buffer WRITERS=8 OPS=200 bundle exec ruby benchmarks/stats_write.rb

gem_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(gem_lib) unless $LOAD_PATH.include?(gem_lib)

polyrun_lib = ENV["PRESSURE_POLYRUN_LIB"] || File.expand_path("../../polyrun.rb/lib", __dir__)
$LOAD_PATH.unshift(polyrun_lib) unless $LOAD_PATH.include?(polyrun_lib)

ENV["RAILS_ENV"] ||= "test"
ENV["ONNI_STATS_WRITE_BENCH"] = "1"

require "json"
require "fileutils"
require "tmpdir"
require "active_support"
require "active_support/core_ext/numeric/time"

dummy_root = File.expand_path("../spec/dummy", __dir__)
require File.join(dummy_root, "config/environment")

require "onni"
require "polyrun/benchmark/pressure"

module Onni
  module Bench
    module StatsWrite
      module_function

      STAGES = %w[setup single_write concurrent_wait buffer_flush lock_busy].freeze
      HOT_KEY = "hot_stats_flag"
      MODES = %w[direct buffer sample].freeze

      def run!
        scenario = ENV.fetch("SCENARIO", "ladder")
        samples = env_int("SAMPLES", 3)
        writers0 = env_int("WRITERS", 1)
        writers1 = env_int("WRITERS_L1", 8)
        ops = env_int("OPS", 200)
        factor = env_float("TARGET_FACTOR", Polyrun::Benchmark::Pressure::DEFAULT_TARGET_FACTOR)

        with_database! do
          case scenario
          when "calibrate"
            exit calibrate! ? 0 : 1
          when "ladder"
            results = ladder!(ops: ops, samples: samples)
          when "matrix"
            results = matrix!(writers0: writers0, writers1: writers1, ops: ops, samples: samples, factor: factor)
          when "observe"
            mode = ENV.fetch("MODE", "direct")
            writers = env_int("WRITERS", writers1)
            results = [observe_mode!(mode: mode, writers: writers, ops: ops, samples: samples)]
          when "gate"
            results = gate!(writers: writers1, ops: ops, samples: samples)
          else
            raise ArgumentError, "Unknown SCENARIO=#{scenario.inspect}"
          end

          path = Polyrun::Benchmark::Pressure.write_results!(
            results,
            repository_root: File.expand_path("..", __dir__),
            name: "stats_write"
          )
          results.each { |row| puts row["report"] }
          puts "wrote #{path}"
          exit(results.any? { |row| row["pass"] == false } ? 1 : 0)
        end
      end

      def with_database!
        bench_dir = File.expand_path("tmp/stats_write_bench", File.expand_path("..", __dir__))
        FileUtils.mkdir_p(bench_dir)
        db_path = File.join(bench_dir, "stats_write.sqlite3")
        FileUtils.rm_f(db_path)
        FileUtils.rm_f("#{db_path}-wal")
        FileUtils.rm_f("#{db_path}-shm")

        pool = env_int("DB_POOL", 32)
        timeout_ms = env_int("DB_TIMEOUT_MS", 5_000)
        journal_mode = ENV.fetch("JOURNAL_MODE", "WAL").upcase
        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: db_path,
          pool: pool,
          timeout: timeout_ms
        )
        ActiveRecord::Schema.verbose = false
        load File.join(dummy_root_path, "db", "schema.rb")
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.execute("PRAGMA journal_mode=#{journal_mode}")
          connection.execute("PRAGMA synchronous=NORMAL")
          connection.execute("PRAGMA busy_timeout=#{timeout_ms}")
        end

        Onni.configure do |config|
          config.features_path = File.join(dummy_root_path, "config/features.yml")
          config.adapter = :active_record
          config.cache = nil
          config.stats_enabled = true
          config.stats_sample_rate = 1.0
          config.stats_scale_sampled_hits = true
          config.stats_buffer = false
          config.stats_ignore = []
          config.stats_sampler = nil
          config.concurrency = :mutex
        end
        Onni.reset_adapter!
        Onni::Registry.reload!
        Onni::Group.clear!
        yield
      ensure
        ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord::Base)
      end

      def dummy_root_path
        File.expand_path("../spec/dummy", __dir__)
      end

      def calibrate!
        walls = {}
        STAGES.each_with_index do |stage, index|
          sleep_s = 0.01 * (index + 1)
          before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sleep sleep_s
          walls[stage] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - before
        end
        order_ok = walls.values.each_cons(2).all? { |a, b| b > a }
        distinct_wall = walls.values.uniq.size == walls.size
        puts({order_ok: order_ok, distinct_wall: distinct_wall, walls: walls}.to_json)
        order_ok && distinct_wall
      end

      def ladder!(ops:, samples:)
        writers_steps = ENV.fetch("WRITERS_STEPS", "1,2,4,8,16").split(",").map { |s| Integer(s.strip) }
        results = []
        writers_steps.each do |writers|
          MODES.each do |mode|
            label = "ladder_w#{writers}_#{mode}_ops#{ops}"
            results << median_sample(label, writers * ops, samples, mode: mode, writers: writers, ops: ops)
          end
        end
        results
      end

      def matrix!(writers0:, writers1:, ops:, samples:, factor:)
        baseline = median_sample(
          "baseline_direct_w#{writers0}_ops#{ops}",
          writers0 * ops,
          samples,
          mode: "direct",
          writers: writers0,
          ops: ops
        )
        pressure = median_sample(
          "pressure_direct_w#{writers1}_ops#{ops}",
          writers1 * ops,
          samples,
          mode: "direct",
          writers: writers1,
          ops: ops
        )
        propose_ceilings!(pressure, factor: factor)
        [baseline, pressure]
      end

      def observe_mode!(mode:, writers:, ops:, samples:)
        label = ENV.fetch("BENCH_LABEL", "observe_#{mode}_w#{writers}_ops#{ops}")
        median_sample(label, writers * ops, samples, mode: mode, writers: writers, ops: ops)
      end

      def gate!(writers:, ops:, samples:)
        ceilings = load_ceilings
        [median_sample(
          "gate_direct_w#{writers}_ops#{ops}",
          writers * ops,
          samples,
          mode: "direct",
          writers: writers,
          ops: ops,
          targets: ceilings
        )]
      end

      def prepare!(mode:)
        Onni::StatBucket.delete_all
        Onni.reset_request!
        Onni.configuration.stats_enabled = true
        Onni.configuration.stats_ignore = []
        Onni.configuration.stats_sampler = nil
        case mode
        when "direct"
          Onni.configuration.stats_buffer = false
          Onni.configuration.stats_sample_rate = 1.0
        when "buffer"
          Onni.configuration.stats_buffer = true
          Onni.configuration.stats_sample_rate = 1.0
        when "sample"
          Onni.configuration.stats_buffer = false
          Onni.configuration.stats_sample_rate = 0.1
        else
          raise ArgumentError, "Unknown MODE=#{mode.inspect}"
        end
        Onni.reset_adapter!
      end

      def run_writers!(mode:, writers:, ops:)
        prepare!(mode: mode)
        errors = Queue.new
        lock_waits = Queue.new
        started = Queue.new
        go = Queue.new

        threads = Array.new(writers) do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              started << true
              go.pop
              ops.times do
                case mode
                when "direct"
                  # Bypass sampler so every hit is one upsert (worst-case lock path).
                  Onni.adapter.record_stat(HOT_KEY, enabled: true, weight: 1)
                when "buffer", "sample"
                  Onni::Stats.record(HOT_KEY, enabled: true)
                else
                  raise ArgumentError, "Unknown MODE=#{mode.inspect}"
                end
              rescue ActiveRecord::StatementInvalid, SQLite3::BusyException, SQLite3::LockedException => error
                lock_waits << error.class.name
                errors << "#{error.class}:#{error.message}"
                break
              rescue => error
                errors << "#{error.class}:#{error.message}"
                break
              end
              if mode == "buffer"
                begin
                  Onni.flush_stats!
                rescue ActiveRecord::StatementInvalid, SQLite3::BusyException, SQLite3::LockedException => error
                  lock_waits << error.class.name
                  errors << "flush:#{error.class}:#{error.message}"
                rescue => error
                  errors << "flush:#{error.class}:#{error.message}"
                end
              end
            end
          end
        end

        writers.times { started.pop }
        writers.times { go << true }
        threads.each(&:join)

        error_list = drain_queue(errors)
        wait_list = drain_queue(lock_waits)
        {
          "errors" => error_list.size,
          "lock_waits" => wait_list.size,
          "error_classes" => error_list.map { |e| e.split(":").first }.tally,
          "hits" => Onni::StatBucket.where(feature_key: HOT_KEY).sum(:enabled_hits)
        }
      end

      def drain_queue(queue)
        list = []
        list << queue.pop(true) while !queue.empty?
        list
      rescue ThreadError
        list
      end

      def median_sample(label, total_ops, samples, mode:, writers:, ops:, targets: nil)
        rows = Array.new(samples) do
          extras_holder = {}
          measured = Polyrun::Benchmark::Pressure.measure(
            label: label,
            ops: total_ops,
            extras: {"targets" => targets}
          ) {
            extras_holder.replace(run_writers!(mode: mode, writers: writers, ops: ops))
          }
          measured["metrics"]["lock_waits"] = extras_holder["lock_waits"].to_i
          measured["metrics"]["write_errors"] = extras_holder["errors"].to_i
          measured["metrics"]["recorded_hits"] = extras_holder["hits"].to_i
          unless targets.nil?
            measured["pass"] = Polyrun::Benchmark::Pressure.targets_met?(measured["metrics"], targets)
          end
          measured["report"] = "#{measured["report"]} | lock_waits=#{extras_holder["lock_waits"]} " \
            "write_errors=#{extras_holder["errors"]} hits=#{extras_holder["hits"]}"
          measured
        end
        pick_median(rows)
      end

      def pick_median(rows)
        sorted = rows.sort_by { |row| row.dig("metrics", "wall_s").to_f }
        sorted[sorted.size / 2]
      end

      def propose_ceilings!(pressure_row, factor:, headroom: 1.25)
        metrics = pressure_row.fetch("metrics")
        ceilings = {
          "wall_s" => metrics["wall_s"] * headroom,
          "cpu_s" => metrics["cpu_s"] * headroom,
          "heap_delta_bytes" => [metrics["heap_delta_bytes"] * headroom, 0].max,
          "lock_waits" => 0,
          "write_errors" => 0
        }
        path = File.expand_path("stats_write_ceilings.json", __dir__)
        File.write(path, JSON.pretty_generate(ceilings))
        puts "proposed ceilings -> #{path} (headroom=#{headroom}; factor=#{factor} reserved; rss omitted)"
        ceilings
      end

      def load_ceilings
        path = File.expand_path("stats_write_ceilings.json", __dir__)
        return nil unless File.file?(path)

        JSON.parse(File.read(path))
      end

      def env_int(name, default)
        Integer(ENV.fetch(name, default))
      end

      def env_float(name, default)
        Float(ENV.fetch(name, default))
      end
    end
  end
end

Onni::Bench::StatsWrite.run!
