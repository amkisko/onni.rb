#!/usr/bin/env ruby
# frozen_string_literal: true

# Pressure / load bench for Onni feature hot paths (memory adapter).
#
# Usage:
#   SCENARIO=calibrate bundle exec ruby benchmarks/load.rb
#   SCENARIO=gate bundle exec ruby benchmarks/load.rb
#   SCENARIO=matrix bundle exec ruby benchmarks/load.rb

gem_lib = ENV["PRESSURE_SOURCE"] ? File.join(ENV["PRESSURE_SOURCE"], "lib") : File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(gem_lib) unless $LOAD_PATH.include?(gem_lib)

polyrun_lib = ENV["PRESSURE_POLYRUN_LIB"] || File.expand_path("../../polyrun.rb/lib", __dir__)
$LOAD_PATH.unshift(polyrun_lib) unless $LOAD_PATH.include?(polyrun_lib)

require "json"
require "tmpdir"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/time"
require "active_support/cache"
require "onni"
require "polyrun/benchmark/pressure"

module Onni
  module Bench
    module Load
      module_function

      # Named stages for meter self-test (distinct known walls).
      STAGES = %w[
        registry
        visible
        boolean
        actor
        percentage
        group
        variant
        conditions
        stats
      ].freeze

      FEATURES_YAML = <<~YAML
        flag_boolean:
          everyone: true
          expires_at: "2099-01-01"
          description: "Global boolean"
        flag_actor:
          expires_at: "2099-01-01"
          description: "Actor gate"
        flag_percentage:
          expires_at: "2099-01-01"
          description: "Percentage of actors"
        flag_group:
          expires_at: "2099-01-01"
          description: "Audience group"
        flag_variant:
          type: experiment
          everyone: true
          expires_at: "2099-01-01"
          description: "A/B variants"
          variants:
            control: 50
            treatment: 50
        flag_conditions:
          everyone: true
          expires_at: "2099-01-01"
          description: "Boolean plus conditions"
          conditions:
            - "beta_tester?"
        flag_stats:
          everyone: true
          expires_at: "2099-01-01"
          description: "Hit stats path"
      YAML

      def run!
        scenario = ENV.fetch("SCENARIO", "matrix")
        samples = env_int("SAMPLES", 3)
        n0 = env_int("BENCH_N", 2_000)
        pressure_mult = env_float("PRESSURE_MULT", 5.0)
        factor = env_float("TARGET_FACTOR", Polyrun::Benchmark::Pressure::DEFAULT_TARGET_FACTOR)

        with_registry! do
          case scenario
          when "calibrate"
            exit calibrate! ? 0 : 1
          when "gate"
            results = gate!(n1: (n0 * pressure_mult).round, samples: samples)
          when "observe"
            # Before/after deltas without rewriting ceilings.
            results = observe!(n1: (n0 * pressure_mult).round, samples: samples)
          when "matrix", "smoke"
            n = (scenario == "smoke") ? 200 : n0
            results = matrix!(n0: n, pressure_mult: pressure_mult, factor: factor, samples: samples)
          else
            raise ArgumentError, "Unknown SCENARIO=#{scenario.inspect}"
          end

          path = Polyrun::Benchmark::Pressure.write_results!(
            results,
            repository_root: File.expand_path("..", __dir__),
            name: "load"
          )
          results.each { |row| puts row["report"] }
          puts "wrote #{path}"
          exit(results.any? { |row| row["pass"] == false } ? 1 : 0)
        end
      end

      def with_registry!
        Dir.mktmpdir("onni-bench") do |dir|
          path = File.join(dir, "features.yml")
          File.write(path, FEATURES_YAML)
          Onni.configure do |config|
            config.features_path = path
            config.adapter = :memory
            config.stats_enabled = false
            config.stats_sample_rate = 1.0
            config.stats_buffer = false
            config.cache = nil
            config.concurrency = :mutex
          end
          Onni.reset_adapter!
          Onni::Registry.reload!
          Onni::Group.clear!
          yield
        end
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

      def matrix!(n0:, pressure_mult:, factor:, samples:)
        results = []
        baseline = median_sample("baseline_all_features", n0, samples) { |actors|
          run_all_features_batch!(n0, actors: actors)
        }
        results << baseline
        n1 = [(n0 * pressure_mult).round, 1].max
        pressure = median_sample("pressure_all_features_#{n1}", n1, samples) { |actors|
          run_all_features_batch!(n1, actors: actors)
        }
        results << pressure
        propose_ceilings!(pressure, factor: factor)
        results
      end

      def gate!(n1:, samples:)
        ceilings = load_ceilings
        [median_sample("gate_all_features_#{n1}", n1, samples, targets: ceilings) { |actors|
          run_all_features_batch!(n1, actors: actors)
        }]
      end

      def observe!(n1:, samples:)
        label = ENV.fetch("BENCH_LABEL", "observe_all_features_#{n1}")
        [median_sample(label, n1, samples) { |actors|
          run_all_features_batch!(n1, actors: actors)
        }]
      end

      # One load unit walks every product evaluate path once (boolean, actor,
      # percentage, group, variant, conditions, sampled stats write).
      def run_all_features_batch!(n, actors:)
        n.times do |i|
          actor = actors[i % actors.size]
          Onni.visible?(:flag_boolean)
          Onni.visible?(:flag_actor, actor)
          Onni.visible?(:flag_percentage, actor)
          Onni.visible?(:flag_group, actor)
          Onni.variant(:flag_variant, actor)
          Onni.visible?(:flag_conditions, actor)
          Onni.visible?(:flag_stats, actor)
        end
        Onni.flush_stats! if Onni.configuration.stats_buffer
      end

      def prepare_features!
        Onni.reset_request!
        Onni.adapter = Onni::Adapters::Memory.new
        Onni::Group.clear!
        Onni.register_group(:staff) { |actor, _| actor.id.even? }

        Onni.ready!(:flag_boolean)
        Onni.visible_actor!(:flag_actor, actor_class.new(0, beta_tester: true))
        Onni.level!(:flag_percentage, 100)
        Onni.visible_group!(:flag_group, :staff)
        Onni.ready!(:flag_variant)
        Onni.variants!(:flag_variant, {control: 50, treatment: 50})
        Onni.ready!(:flag_conditions)
        Onni.ready!(:flag_stats)

        Onni.configuration.stats_enabled = true
        Onni.configuration.stats_sample_rate = 0.1
        Onni.configuration.stats_scale_sampled_hits = true
        Onni.configuration.stats_buffer = %w[1 true yes].include?(ENV["BENCH_STATS_BUFFER"]&.downcase)

        Onni.preload! if %w[1 true yes].include?(ENV["BENCH_PRELOAD"]&.downcase)
      end

      def actor_class
        @actor_class ||= Class.new do
          def initialize(id, beta_tester: false)
            @id = id
            @beta_tester = beta_tester
          end

          attr_reader :id

          def beta_tester?
            @beta_tester
          end

          def self.name = "User"
        end
      end

      def median_sample(label, ops, samples, targets: nil)
        actors = Array.new([ops / 10, 1].max) { |i| actor_class.new(i, beta_tester: i.even?) }
        rows = Array.new(samples) do
          # Setup outside the timed section so ceilings track evaluate cost.
          prepare_features!
          Polyrun::Benchmark::Pressure.measure(label: label, ops: ops, extras: {"targets" => targets}) {
            yield(actors)
          }
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
          "heap_delta_bytes" => [metrics["heap_delta_bytes"] * headroom, 0].max
        }
        path = File.expand_path("ceilings.json", __dir__)
        File.write(path, JSON.pretty_generate(ceilings))
        puts "proposed ceilings -> #{path} (headroom=#{headroom}; factor=#{factor} reserved for tighten; rss omitted)"
        ceilings
      end

      def load_ceilings
        path = File.expand_path("ceilings.json", __dir__)
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

Onni::Bench::Load.run! if $PROGRAM_NAME == __FILE__
