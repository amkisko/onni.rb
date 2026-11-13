# frozen_string_literal: true

root = ENV.fetch("PRESSURE_SOURCE")
$LOAD_PATH.unshift(File.join(root, "lib"))
probe = ENV.fetch("PROBE", "standalone")

case probe
when "active_support"
  require "active_support"
  require "active_support/core_ext/numeric/time"
  require "active_support/core_ext/object/blank"
when "rails", "rails_extension", "active_admin_extension"
  require "rails/all"
  require "activeadmin" if probe == "active_admin_extension"
when "standalone", "standalone_ready", "control"
else raise ArgumentError, "Unknown boot probe #{probe}"
end

entry = ENV.fetch("BOOT_ENTRY", "onni")
if probe == "rails_extension"
  entry = File.file?(File.join(root, "lib/onni/rails.rb")) ? "onni/rails" : "onni"
elsif probe == "active_admin_extension"
  entry = "onni/active_admin"
end

GC.start
loaded_before = $LOADED_FEATURES.size
allocations = GC.stat(:total_allocated_objects)
cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require entry unless probe == "control"
if probe == "standalone_ready"
  Onni.configuration.features_path = ENV.fetch("BOOT_FEATURES")
  Onni.ready!(:new_checkout)
  visible = Onni.visible?(:new_checkout)
end
metrics = {
  "wall_s" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
  "cpu_s" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu,
  "allocated_objects" => GC.stat(:total_allocated_objects) - allocations,
  "loaded_files" => $LOADED_FEATURES.size - loaded_before,
  "live_heap_slots" => GC.stat(:heap_live_slots)
}
contract = (probe == "control") ? {"empty_control" => true} : {"version_loaded" => !!defined?(Onni::VERSION)}
if probe == "standalone_ready"
  contract["visible"] = visible
  contract["shown_count"] = Onni::Stats.for(:new_checkout).sum { |row| row.fetch("shown_count") }
end

require "json"
metrics.merge!(
  "contract" => contract,
  "entry" => entry,
  "store_bytes" => 0,
  "source_bytes" => Dir[File.join(root, "{lib,app,sig}/**/*")]
    .select { |path| File.file?(path) }.sum { |path| File.size(path) }
)
puts JSON.generate(metrics)
