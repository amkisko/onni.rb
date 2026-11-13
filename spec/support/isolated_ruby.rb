# frozen_string_literal: true

require "open3"
require "rbconfig"
require "json"

module IsolatedRuby
  def isolated_ruby(program, *arguments, coverage_name:)
    root = File.expand_path("../..", __dir__)
    script = <<~RUBY
      measuring = ENV["POLYRUN_COVERAGE"] == "1"
      if measuring
        require "coverage"
        Coverage.start(lines: true)
      end
      begin
        #{program}
      ensure
        if measuring
          require "polyrun/coverage/collector"
          root = ENV.fetch("ONNI_SPEC_ROOT")
          Polyrun::Coverage::Collector.start!(
            root: root, track_under: %w[lib app],
            output_path: File.join(root, "coverage/polyrun-fragment-#{coverage_name}.json")
          )
        end
      end
    RUBY
    output, errors, status = Open3.capture3(
      {"ONNI_SPEC_ROOT" => root}, RbConfig.ruby, "-rbundler/setup", "-I#{root}/lib", "-e", script, *arguments
    )
    expect(status.success?).to be(true), errors
    JSON.parse(output)
  end
end
