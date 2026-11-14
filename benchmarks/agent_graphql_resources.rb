# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "digest"
require "time"

module AgentGraphqlResources
  module_function

  def directory_bytes(directory)
    Dir.glob(File.join(directory, "**", "*"), File::FNM_DOTMATCH)
      .select { |path| File.file?(path) && !File.symlink?(path) }
      .sum { |path| File.size(path) }
  end

  def sample
    require "bundler/setup"
    ENV["RAILS_ENV"] = "test"
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    require File.expand_path("spec/dummy/config/environment", Dir.pwd)
    elapsed_cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu
    elapsed_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall
    packages = Bundler.definition.specs.reject { |spec| spec.name == "onni" }
    graph_bytes = packages.sum { |spec| directory_bytes(spec.full_gem_path) }
    puts JSON.generate(cpu_ms: elapsed_cpu * 1000, wall_ms: elapsed_wall * 1000,
      graph_bytes: graph_bytes, package_count: packages.length,
      runtime_dependency_count: Gem.loaded_specs.fetch("onni").runtime_dependencies.length)
  end

  def source_hash(root)
    patterns = %w[lib/**/* app/**/* config/**/* sig/**/* spec/dummy/config/**/* spec/dummy/app/**/*
      spec/dummy/db/*.rb Gemfile Gemfile.lock onni.gemspec README.md]
    paths = patterns.flat_map { |pattern| Dir.glob(File.join(root, pattern)) }.select { |path| File.file?(path) }.sort
    Digest::SHA256.hexdigest(paths.map { |path| path.delete_prefix(root) + "\0" + File.binread(path) }.join)
  end

  def capture(root)
    environment = {"BUNDLE_GEMFILE" => File.join(root, "Gemfile"), "BUNDLE_IGNORE_CONFIG" => "1"}
    stdout, stderr, status = Open3.capture3(environment, "/usr/bin/time", "-l", RbConfig.ruby, File.expand_path(__FILE__), "--sample", chdir: root)
    raise "Boot sample failed: #{stderr}" unless status.success?

    peak = stderr.match(/^\s*(\d+)\s+maximum resident set size$/)
    raise "Peak RSS meter missing" unless peak

    JSON.parse(stdout.lines.last).merge("peak_rss_bytes" => Integer(peak[1]))
  end

  def artifact(root, output)
    environment = {"BUNDLE_GEMFILE" => File.join(root, "Gemfile"), "BUNDLE_IGNORE_CONFIG" => "1"}
    _, stderr, status = Open3.capture3(environment, RbConfig.ruby, "-S", "gem", "build", "onni.gemspec", "--output", output, chdir: root)
    raise "Gem build failed: #{stderr}" unless status.success?

    File.size(output)
  end

  def run
    return sample if ARGV.include?("--sample")
    raise "Peak RSS parser calibrated for Darwin time -l only" unless RUBY_PLATFORM.include?("darwin")

    started_at = Time.now.utc.iso8601
    base = File.expand_path(ENV.fetch("BASE", "tmp/graphql-base"))
    head = File.expand_path(ENV.fetch("HEAD", "."))
    rows = {"base" => [], "head" => []}
    3.times do |index|
      order = index.even? ? %w[base head] : %w[head base]
      order.each { |label| rows[label] << capture(label == "base" ? base : head) }
    end
    medians = rows.transform_values do |samples|
      samples.first.keys.to_h { |key| [key, samples.map { |sample| sample.fetch(key) }.sort.fetch(1)] }
    end
    artifacts = {"base" => artifact(base, File.join(head, "tmp/onni-before-agent.gem")),
                 "head" => artifact(head, File.join(head, "tmp/onni-after-agent.gem"))}
    puts JSON.pretty_generate(started_at: started_at, finished_at: Time.now.utc.iso8601,
      base: "pre-task working-tree snapshot", head: "current working tree",
      base_source_sha256: source_hash(base), head_source_sha256: source_hash(head),
      revision: `git rev-parse HEAD`.strip, machine: RbConfig::CONFIG["arch"],
      ruby: RUBY_VERSION, probe: "dummy ActiveAdmin boot", memory: "process_lifetime",
      energy_proxy: "cpu_ms", network: "not_in_scope", warmup: "fresh process, no warmup",
      samples: rows, medians: medians, compressed_gem_bytes: artifacts,
      delta: medians["head"].to_h { |key, value| [key, value - medians["base"].fetch(key)] },
      gem_delta_bytes: artifacts["head"] - artifacts["base"])
  end
end

AgentGraphqlResources.run
