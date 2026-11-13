# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "../../spec/support/audience_filter_cases"

root = File.expand_path("../..", __dir__)
Dir.chdir(root)
specification = "spec/onni/audience_filter_matrix_spec.rb"
output = "tmp/audience-filter-mutations"
FileUtils.mkdir_p(output)
ready = "experiment with weights from runtime while ready"
mutations = [
  ["everyone_bypasses_filters", "audience.rb", ' && !actor_scoped?(filters)', "", ready],
  ["missing_default_closed", "audience.rb", "      return false unless opened?(filters)\n", "", ready],
  ["empty_group_opens", "audience.rb", 'filters["groups"]&.none?', 'filters["groups"]&.any? && filters["groups"].none?', ready],
  ["group_excludes_ignored", "audience.rb", "      return false if filters[\"excluded_groups\"]&.any? { |group| Group.member?(group, actor) }\n", "", ready],
  ["actor_excludes_ignored", "audience.rb", "      return false if excluded&.include?(identity)\n", "", ready],
  ["percentage_boundary_inclusive", "audience.rb", " >= level", " > level", ready],
  ["assignment_bypasses_audience", "store.rb", "weights.values.sum.positive? && matches?(name, actor, definition, gates)", "weights.values.sum.positive?", ready],
  ["ordinary_flag_assigns_variant", "store.rb", "      return unless Settings.type(definition) == \"experiment\"\n", "", "ordinary flag from runtime while ready"],
  ["update_readies_parked_flag", "mutations.rb", "        write_filters(gates, changes)\n", "        write_filters(gates, changes)\n        power(gates)\n", "experiment with weights from runtime while parked"],
  ["park_erases_settings", "mutations.rb", 'mutate(name, :park) { |gates, _| set_gate(gates, "powered", "false") }', 'mutate(name, :park) { |gates, _| gates.clear; set_gate(gates, "powered", "false") }', ready],
  ["removed_filter_keeps_default", "settings.rb", "definition.merge(overrides)", "definition.merge(overrides.compact)", ready],
  ["partial_update_loses_filters", "mutations.rb", "GateSnapshot.wrap(gates).filters.merge(changes)", "changes", "removed defaults for experiment with weights"],
  ["conditions_ignored", "store.rb", "      Conditions.met?(name, actor, definition: definition)", "      true", "applies conditions to every filter-presence combination for experiment with weights"],
  ["expiry_ignored", "store.rb", "      return false if expired?(definition)\n", "", "applies expired to every filter-presence combination for experiment with weights"]
]

def run_specs(command, destination)
  FileUtils.rm_f(destination)
  stdout, stderr, status = Open3.capture3({"POLYRUN_COVERAGE" => "0", "POLYRUN_COVERAGE_DISABLE" => "1"}, *command)
  File.write("#{destination}.log", stdout + stderr)
  report = File.exist?(destination) ? JSON.parse(File.read(destination)) : {}
  [status.exitstatus, report]
end

destination = "#{output}/unmodified.json"
command = ["bundle", "exec", "rspec", specification, "--format", "json", "--out", destination]
status, baseline = run_specs(command, destination)
raise "Unmodified matrix failed; see #{destination}.log" unless status == 0

families = baseline.fetch("examples").group_by do |example|
  description = example.fetch("description")
  if description.start_with?("checks all filter update orders") then "order"
  elsif description.start_with?("checks inherited") then "precedence"
  elsif description.start_with?("checks ") then "composition"
  elsif description.start_with?("applies ") && description.include?("filter-presence combination") then "restrictions"
  else raise "Unregistered matrix profile: #{description}"
  end
end
case_counts = {
  "composition" => families.fetch("composition").size * AudienceFilterCases::ROWS.size,
  "precedence" => families.fetch("precedence").size * AudienceFilterCases.precedence_rows.size,
  "restrictions" => families.fetch("restrictions").size * AudienceFilterCases.presence_rows.size,
  "order" => families.fetch("order").size * AudienceFilterCases::DIMENSIONS.keys.permutation.count
}
park_cases = families.fetch("composition").count { |entry| entry.fetch("description").end_with?("while ready") } * AudienceFilterCases::ROWS.size
resume_cases = families.fetch("composition").count { |entry| !entry.fetch("description").end_with?("while pending") } * AudienceFilterCases::ROWS.size

bootstrap = <<~RUBY
  directory = ARGV.shift
  $LOAD_PATH.unshift(directory)
  require "onni"
  abort "Wrong source tree" unless File.identical?(Onni::Audience.method(:matches?).source_location.first, File.join(directory, "onni/audience.rb"))
  load Gem.bin_path("rspec-core", "rspec")
RUBY
results = mutations.map do |name, path, original, replacement, example|
  Dir.mktmpdir("onni-filter-mutation") do |directory|
    FileUtils.cp_r("lib", directory)
    path = File.join(directory, "lib/onni", path)
    source = File.read(path)
    raise "Mutation target changed: #{name}" unless source.scan(Regexp.new(Regexp.escape(original))).size == 1

    File.write(path, source.sub(original, replacement))
    destination = "#{output}/#{name}.json"
    command = ["bundle", "exec", "ruby", "-e", bootstrap, File.join(directory, "lib"),
      specification, "--example", example, "--fail-fast", "--format", "json", "--out", destination]
    status, report = run_specs(command, destination)
    summary = report.fetch("summary", {})
    failed = report.fetch("examples", []).select { |entry| entry["status"] == "failed" }
    killed = status == 1 && summary["failure_count"].to_i.positive? &&
      summary["errors_outside_of_examples_count"] == 0 &&
      failed.all? { |entry| entry.dig("exception", "class") == "RSpec::Expectations::ExpectationNotMetError" }
    puts "#{name}: #{killed ? "detected" : "NOT DETECTED"}"
    {name: name, detected: killed, summary: summary, example: example}
  end
end

digest = Digest::SHA256.new
Dir["{lib,app,sig}/**/*"].select { |path| File.file?(path) }.sort.each { |path| digest << "/#{path}" << File.binread(path) }
report = {
  command: "bundle exec ruby usr/scripts/check_audience_filter_matrix.rb",
  product_digest: digest.hexdigest,
  test_digests: [specification, "spec/support/audience_filter_cases.rb", "usr/scripts/check_audience_filter_matrix.rb"].to_h { |path| [path, Digest::SHA256.file(path).hexdigest] },
  dimensions: AudienceFilterCases::DIMENSIONS.transform_values { |states| states.map(&:label) },
  unique_filter_combinations: AudienceFilterCases::ROWS.size,
  profiles: families.transform_values(&:size), case_counts: case_counts,
  park_cases: park_cases, resume_cases: resume_cases,
  actor_cases: AudienceFilterCases::UNIVERSE,
  apis: %w[visible? variant],
  configuration_readers: %w[Flag#power_state Flag#filters Flag#variants],
  public_api_evaluations: (case_counts.values.sum + park_cases + resume_cases) * AudienceFilterCases::UNIVERSE.size * 2,
  unmodified: baseline.fetch("summary"), mutations: results,
  pass: results.all? { |entry| entry.fetch(:detected) }
}
destination = "benchmarks/audience_filter_matrix_results.json"
File.write(destination, JSON.pretty_generate(report) + "\n")
puts "Saved #{destination}"
exit(report.fetch(:pass) ? 0 : 1)
