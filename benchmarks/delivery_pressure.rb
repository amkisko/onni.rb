# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "rbconfig"
require_relative "../lib/onni"

module DeliveryPressure
  STAGES = %w[success fallback observe export].freeze
  module_function

  def percentile(values)
    values.sort.fetch((values.length * 0.95).ceil - 1)
  end

  def measure(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    start = clock.call
    yield
    (clock.call - start) * 1_000_000
  end

  def calibrate
    raise "RSS parser failed" unless peak_rss("  12345 maximum resident set size\n") == 12345
    known = [11.0, 23.0, 37.0, 53.0]
    observed = STAGES.zip(known).to_h do |name, value|
      ticks = [0.0, value / 1_000_000]
      [name, measure(clock: -> { ticks.shift }) {}]
    end
    raise "stage calibration failed" unless observed.values.zip(known).all? { |a, b| (a - b).abs < 0.001 }
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stage = measure { sleep 0.005 }
    wall = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - before) * 1_000_000
    raise "aggregate calibration failed" unless stage >= 5_000 && wall >= stage
    {calibration: "pass", known_p95_us: observed, direct_stage_us: stage, aggregate_wall_us: wall}
  end

  def peak_rss(stderr)
    match = stderr.match(/^\s*(\d+)\s+maximum resident set size$/)
    raise "peak RSS meter unavailable" unless match
    Integer(match[1])
  end

  def setup
    Onni.configuration.features_path = nil
    Onni.configuration.cache = nil
    Onni.configuration.stats_enabled = false
    if ENV["ADAPTER"] == "active_record"
      require "tmpdir"
      require "onni/active_record"
      @database_directory = Dir.mktmpdir("onni-delivery-pressure-")
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(@database_directory, "pressure.sqlite3"), pool: 16, timeout: 5000)
      ActiveRecord::Schema.verbose = false
      load File.expand_path("../spec/dummy/db/schema.rb", __dir__)
      Onni.configuration.adapter = :active_record
      Onni.reset_adapter!
    end
    Onni.define!(:new_checkout, description: "Delivery pressure fixture", expires_at: "2099-01-01")
    Class.new(Onni::Delivery) do
      feature :new_checkout
      parked { |fail: false| :legacy }
      experiment(:new_flow, everyone: true) do |fail: false|
        raise IOError, "fixture" if fail
        :new
      end
    end
  end

  def sample(owner, writers:, operations:)
    if ENV["ADAPTER"] == "active_record"
      Onni::Gate.delete_all
      Onni::Feature.delete_all
    else
      Onni.adapter.clear!
    end
    Onni.ready!(:new_checkout)
    # Warm all stages outside the measured load.
    owner.call
    owner.call(fail: true)
    Onni.observe!(:new_checkout, :exception)
    Onni.export_catalogue(format: :json)
    Onni.reset_signals!(:new_checkout)
    times = STAGES.to_h { |name| [name, Queue.new] }
    errors = Queue.new
    cpu_start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    threads = Array.new(writers) do
      Thread.new do
        operations.times do
          times["success"] << measure { raise "wrong success" unless owner.call == :new }
          times["fallback"] << measure { raise "wrong fallback" unless owner.call(fail: true) == :legacy }
          times["observe"] << measure { Onni.observe!(:new_checkout, :exception) }
          times["export"] << measure { JSON.parse(Onni.export_catalogue(format: :json, runtime: true)) }
        end
      rescue => error
        errors << error.class.name
      end
    end
    threads.each(&:join)
    wall_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
    cpu_ms = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu_start) * 1000
    result = {"wall_ms" => wall_ms, "cpu_ms" => cpu_ms, 
              "write_errors" => errors.size,
              "level_error" => (Onni.signal_level(:new_checkout, :exception) - writers * operations * 2).abs,
              "storage_bytes" => JSON.generate(Onni.adapter.gates_for(:new_checkout)).bytesize,
              "shipped_source_bytes" => Dir["{lib,app,sig}/**/*"].select { |path| File.file?(path) }.sum { |path| File.size(path) }}
    times.each do |name, queue|
      values = []
      values << queue.pop until queue.empty?
      result["#{name}_p95_us"] = values.empty? ? 1e12 : percentile(values)
    end
    if @database_directory
      result["storage_bytes"] = Dir[File.join(@database_directory, "*")].sum { |path| File.size(path) }
    end
    result
  end

  def run
    if ARGV.include?("--calibrate")
      puts JSON.pretty_generate(calibrate)
      return
    end
    started_at = Time.now.utc.iso8601
    samples = Integer(ENV.fetch("SAMPLES", "3"))
    raise "at least three samples required" if samples < 3
    if ARGV.include?("--sample")
      begin
        puts JSON.generate(sample(setup, writers: Integer(ENV.fetch("WRITERS", "8")), operations: Integer(ENV.fetch("OPS", "100"))))
      ensure
        if @database_directory
          ActiveRecord::Base.connection_pool.disconnect!
          FileUtils.remove_entry(@database_directory)
        end
      end
      return
    end
    writers = Integer(ENV.fetch("WRITERS", "8"))
    operations = Integer(ENV.fetch("OPS", "100"))
    rows = Array.new(samples) do
      stdout, stderr, status = Open3.capture3("/usr/bin/time", "-l", RbConfig.ruby, __FILE__, "--sample")
      raise stderr unless status.success?
      JSON.parse(stdout).merge("rss_bytes" => peak_rss(stderr))
    end
    ceilings_path = ENV["CEILINGS"]
    ceilings = ceilings_path ? JSON.parse(File.read(ceilings_path)) : {}
    maxima = rows.first.keys.to_h { |key| [key, rows.map { |row| row.fetch(key) }.max] }
    failures = ceilings.filter_map { |key, ceiling| key if maxima.fetch(key) > ceiling }
    sources = Dir["{lib,app,sig}/**/*"].select { |path| File.file?(path) }.sort
    source_digest = Digest::SHA256.hexdigest(sources.map { |path| path + "\0" + File.binread(path) }.join)
    result = {started_at: started_at, finished_at: Time.now.utc.iso8601,
              source_sha256: source_digest, probe_sha256: Digest::SHA256.file(__FILE__).hexdigest,
              worktree: "uncommitted implementation", adapter: ENV.fetch("ADAPTER", "memory"), revision: `git rev-parse HEAD`.strip, machine: RbConfig::CONFIG["arch"],
              memory: "process_lifetime", network: "not_in_scope", energy_proxy: "cpu_ms",
              writers: writers, operations: operations, samples: rows, max: maxima, failed: failures}
    puts JSON.pretty_generate(result)
    exit 1 unless failures.empty? && rows.all? { |row| row["write_errors"].zero? && row["level_error"].zero? }
  end
end

DeliveryPressure.run if $PROGRAM_NAME == __FILE__
