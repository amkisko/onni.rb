# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "digest"
require "rbconfig"
require "time"

module PressureRunner
  module_function

  def source_digest(root)
    files = Dir[File.join(root, "{lib,app,sig}/**/*")].select { |path| File.file?(path) }.sort
    digest = Digest::SHA256.new
    files.each { |path| digest << path.delete_prefix(root) << File.binread(path) }
    digest.hexdigest
  end

  def sample(root, probe, count)
    raise "Native RSS parser currently supports Darwin only" unless RUBY_PLATFORM.include?("darwin")

    probe_path = ENV["PRESSURE_PROBE"] || File.join(root, "benchmarks", "pressure_probe.rb")
    probe_path = File.join(__dir__, "pressure_probe.rb") unless File.file?(probe_path)
    output, resources, status = Open3.capture3(
      {"PRESSURE_SOURCE" => File.expand_path(root), "PROBE" => probe, "N" => count.to_s},
      "/usr/bin/time", "-l", RbConfig.ruby, "-rbundler/setup", probe_path
    )
    raise "Probe failed: #{output}\n#{resources}" unless status.success?

    rss = resources[/^\s*(\d+)\s+maximum resident set size\s*$/, 1]
    raise "Native peak RSS unavailable; refusing a zero memory sample" unless rss && rss.to_i.positive?

    JSON.parse(output).merge("peak_rss_bytes" => rss.to_i)
  end

  def summary(rows)
    %w[cpu_s wall_s allocated_objects peak_rss_bytes store_bytes source_bytes].to_h do |metric|
      values = rows.map { |row| row.fetch(metric) }.sort
      value = %w[peak_rss_bytes store_bytes source_bytes].include?(metric) ? values.last : values.fetch(values.size / 2)
      [metric, value]
    end
  end

  def run
    mode = ARGV.fetch(0, "measure")
    raise "Unknown pressure mode #{mode}" unless %w[calibrate measure compare snapshot gate].include?(mode)
    probe = (mode == "calibrate") ? "calibrate" : ENV.fetch("PROBE", "all")
    count = (mode == "calibrate") ? 1 : Integer(ENV.fetch("N", "100000"))
    samples = Integer(ENV.fetch("SAMPLES", "5"))
    raise "At least three samples are required" if samples < 3

    before = File.expand_path(ENV.fetch("BEFORE", "."))
    after = File.expand_path(ENV.fetch("AFTER", "."))
    if mode == "snapshot"
      destination = ENV.fetch("SNAPSHOT")
      FileUtils.mkdir_p(destination)
      %w[lib app sig].each { |path| FileUtils.cp_r(path, File.join(destination, path)) }
      FileUtils.mkdir_p(File.join(destination, "benchmarks"))
      %w[load.rb pressure_probe.rb pressure_runner.rb].each do |path|
        FileUtils.cp(File.join("benchmarks", path), File.join(destination, "benchmarks", path))
      end
      puts "Snapshot #{source_digest(File.expand_path(destination))}"
      return
    end

    result = {"mode" => mode, "started_at" => Time.now.utc.iso8601, "machine_class" => "#{RUBY_PLATFORM}/Ruby #{RUBY_VERSION}",
              "probe" => probe, "count" => count, "samples" => samples, "network" => "not_in_scope",
              "memory" => "process_lifetime", "energy_proxy" => "cpu_s"}
    result["harness_digest"] = Digest::SHA256.hexdigest(%w[load.rb pressure_probe.rb pressure_runner.rb].map { |name| File.binread(File.join(__dir__, name)) }.join)
    result["probe_digest"] = Digest::SHA256.file(ENV["PRESSURE_PROBE"]).hexdigest if ENV["PRESSURE_PROBE"]
    result["revision"] = Open3.capture2("git", "rev-parse", "HEAD").first.strip
    if mode == "calibrate"
      rows = Array.new(samples) { sample(after, "calibrate", 1) }
      raise "RSS allocation fixture was not observed" unless rows.all? { |row| row.fetch("peak_rss_bytes") > 32 * 1024 * 1024 }
      result["calibration"] = rows
    else
      roots = (mode == "compare") ? {"before" => before, "after" => after} : {"after" => after}
      result["source_digests"] = roots.transform_values { |root| source_digest(root) }
      result["raw"] = roots.transform_values { [] }
      samples.times do |index|
        order = index.odd? ? roots.to_a.reverse : roots.to_a
        order.each { |label, root| result["raw"].fetch(label) << sample(root, probe, count) }
      end
      result["summary"] = result["raw"].transform_values { |rows| summary(rows) }
      raise "Source changed during measurement" unless roots.transform_values { |root| source_digest(root) } == result["source_digests"]
      if mode == "compare"
        result["ratios"] = result["summary"].fetch("before").to_h do |metric, baseline|
          [metric, baseline.zero? ? nil : result["summary"].fetch("after").fetch(metric).fdiv(baseline)]
        end
        primary = ENV.fetch("PRIMARY", "cpu_s")
        noise = Float(ENV.fetch("NOISE", "0.03"))
        result["primary"] = primary
        result["noise_floor"] = noise
        result["improved"] = result["ratios"].fetch(primary) <= 1.0 - noise
      end
      if mode == "gate"
        limits = JSON.parse(File.read(ENV.fetch("CEILINGS"))).fetch("limits")
        result["gates"] = limits.to_h do |metric, limit|
          [metric, result["summary"].fetch("after").fetch(metric) <= limit]
        end
        result["pass"] = result["gates"].values.all?
      end
    end
    result["finished_at"] = Time.now.utc.iso8601
    destination = ENV.fetch("OUT", "benchmarks/output/pressure_#{Time.now.utc.strftime("%Y%m%d%H%M%S")}.json")
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, JSON.pretty_generate(result) + "\n")
    puts JSON.generate(result.slice("probe", "summary", "ratios", "gates", "pass"))
    puts "Saved #{destination}"
    exit 1 if result["pass"] == false
  end
end

PressureRunner.run
