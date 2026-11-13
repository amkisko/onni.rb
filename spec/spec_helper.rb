# frozen_string_literal: true

polyrun_cov_measure =
  ENV["POLYRUN_COVERAGE_DISABLE"] != "1" &&
  %w[1 true yes].include?(ENV["POLYRUN_COVERAGE"]&.to_s&.downcase)

if polyrun_cov_measure
  require "coverage"
  branch = %w[1 true yes].include?(ENV["POLYRUN_COVERAGE_BRANCHES"]&.to_s&.downcase)
  ::Coverage.start(lines: true, branches: branch)
end

if polyrun_cov_measure
  require "polyrun/coverage/rails"
  Polyrun::Coverage::Rails.start!(root: File.expand_path("..", __dir__))
end

require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/time"
require "active_support/cache"
require "onni"
require "onni/active_support"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# CI: RSpec JSON (+ JUnit on single-process exit). Sharded workers write
# tmp/rspec-<shard>.json; merge with `polyrun report-junit -i tmp/rspec-*.json`.
require "polyrun/rspec_support"
Polyrun::RSpecSupport.install_sharded_formatter_compat!
Polyrun::RSpecSupport.install_failure_fragments!
Polyrun::RSpecSupport.install_worker_ping!
Polyrun::RSpecSupport.install_example_debug!
Polyrun::RSpecSupport.install_example_rails_logging!
Polyrun::RSpecSupport.install_example_timeout!
Polyrun::RSpecSupport.install_example_prosopite!
if %w[1 true yes].include?(ENV["POLYRUN_SPEC_QUALITY"]&.to_s&.downcase)
  Polyrun::RSpecSupport.install_spec_quality!
end

require "polyrun/reporting/rspec_junit"
shard = ENV["POLYRUN_SHARD_INDEX"]
Polyrun::Reporting::RspecJunit.install!(
  json_path: shard ? "tmp/rspec-#{shard}.json" : "rspec.json",
  junit_path: shard ? "tmp/junit-#{shard}.xml" : "coverage/junit-coverage.xml"
)
