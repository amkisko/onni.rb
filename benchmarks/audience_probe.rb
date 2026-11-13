# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(ENV.fetch("PRESSURE_SOURCE"), "lib"))
require "onni"
require "tmpdir"

probe = ENV.fetch("PROBE", "composed")
count = Integer(ENV.fetch("N", "100000"))
composable = Onni.respond_to?(:filters!)
actor_class = Struct.new(:id) do
  def feature_actor_id = "User;#{id}"
end
actor = (0..100).map { |id| actor_class.new(id) }.find do |candidate|
  candidate.id.even? && Onni::Actor.percentage_value(candidate, "new_checkout") < 25
end
raise "Missing passing actor" unless actor

definitions = if composable
  {"new_checkout" => {}, "audience" => {}, "selected" => {}, "blocked_group" => {}, "blocked_actor" => {}}
else
  {"new_checkout" => {"type" => (probe == "global" ? "boolean" : "percentage")},
   "audience" => {"type" => "group"}, "selected" => {"type" => "actors"},
   "blocked_group" => {"type" => "group"}, "blocked_actor" => {"type" => "actors"}}
end

Dir.mktmpdir("onni-audience-probe") do |directory|
  path = File.join(directory, "features.yml")
  File.write(path, JSON.generate(definitions))
  Onni.configure do |configuration|
    configuration.features_path = path
    configuration.stats_enabled = false
    configuration.adapter = :memory
    configuration.concurrency = :mutex
  end
  Onni::Registry.reload!
  Onni::Group.clear!
  Onni.register_group(:staff) { |_, _| false }
  Onni.register_group(:beta_testers) { |candidate, _| candidate.id.even? }
  Onni.register_group(:blocked) { |_, _| false }
  if composable
    filters = case probe
    when "global" then {everyone: true}
    when "group" then {groups: %w[staff beta_testers]}
    when "percentage" then {level: 25}
    when "composed_typical" then {groups: %w[staff beta_testers], level: 25}
    when "composed" then {groups: %w[staff beta_testers], actors: [actor.feature_actor_id],
                          excluded_groups: ["blocked"], excluded_actors: ["User;999"], level: 25}
    else raise "Unknown probe #{probe}"
    end
    Onni.filters!(:new_checkout, **filters)
    Onni.ready!(:new_checkout)
    candidate = (probe == "global") ? nil : actor
    call = -> { Onni.visible?(:new_checkout, candidate, record_stats: false) }
  else
    Onni.ready!(:new_checkout) if probe == "global"
    Onni.level!(:new_checkout, 25) unless %w[global group].include?(probe)
    if %w[group composed_typical composed].include?(probe)
      Onni.visible_group!(:audience, :staff)
      Onni.visible_group!(:audience, :beta_testers)
    end
    if probe == "composed"
      Onni.visible_actor!(:selected, actor)
      Onni.visible_group!(:blocked_group, :blocked)
      Onni.visible_actor!(:blocked_actor, actor_class.new(999))
    end
    call = case probe
    when "global" then -> { Onni.visible?(:new_checkout, record_stats: false) }
    when "percentage" then -> { Onni.visible?(:new_checkout, actor, record_stats: false) }
    when "group" then -> { Onni.visible?(:audience, actor, record_stats: false) }
    when "composed_typical" then -> { Onni.visible?(:audience, actor, record_stats: false) && Onni.visible?(:new_checkout, actor, record_stats: false) }
    when "composed" then -> {
      Onni.visible?(:selected, actor, record_stats: false) && !Onni.visible?(:blocked_actor, actor, record_stats: false) && Onni.visible?(:new_checkout, actor, record_stats: false) &&
        Onni.visible?(:audience, actor, record_stats: false) && !Onni.visible?(:blocked_group, actor, record_stats: false)
    }
    else raise "Unknown probe #{probe}"
    end
  end
  raise "Audience contract failed" unless call.call
  1_000.times { call.call }
  GC.start
  allocations = GC.stat(:total_allocated_objects)
  cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  count.times { call.call }
  metrics = {
    "cpu_s" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu,
    "wall_s" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall,
    "allocated_objects" => GC.stat(:total_allocated_objects) - allocations,
    "store_bytes" => Onni.adapter.feature_keys.sum { |key| JSON.generate(Onni.adapter.gates_for(key)).bytesize },
    "source_bytes" => Dir[File.join(ENV.fetch("PRESSURE_SOURCE"), "{lib,app,sig}/**/*")].select { |file| File.file?(file) }.sum { |file| File.size(file) }
  }
  puts JSON.generate(metrics)
end
