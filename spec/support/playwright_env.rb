# frozen_string_literal: true

# Detect Playwright CLI and a usable Chromium install for system specs.
# Prefer the dummy-pinned playwright-core (matches playwright-ruby-client).
# Do not fall back to bare `npx playwright` — that floats to a newer CLI and
# asks for a Chromium revision that is not installed.
require "open3"
require "shellwords"

module PlaywrightEnv
  module_function

  def ready?
    return @ready if defined?(@ready)

    @ready = !cli_executable.nil? && browser_installed?
  end

  def cli_available?
    ready?
  end

  def cli_executable
    return @cli_executable if defined?(@cli_executable)

    @cli_executable = detect_executable
  end

  def hint
    if cli_executable.nil?
      "Browser CLI not found. From the repo root: " \
        "npm --prefix spec/dummy install && " \
        "./spec/dummy/node_modules/.bin/playwright-core install chromium"
    elsif !browser_installed?
      "Chromium is not installed for the browser CLI. From the repo root: " \
        "./spec/dummy/node_modules/.bin/playwright-core install chromium"
    else
      "Browser driver is not ready for system specs."
    end
  end

  def detect_executable
    candidates = []
    path = ENV["PLAYWRIGHT_CLI_EXECUTABLE_PATH"].to_s.strip
    candidates << path unless path.empty?
    candidates << Rails.root.join("node_modules/.bin/playwright-core").to_s
    candidates << "npx --no-install playwright-core"

    candidates.find { |candidate| version_ok?(candidate) }
  rescue Errno::ENOENT
    nil
  end

  def version_ok?(command)
    argv = command.shellsplit
    _out, status = Open3.capture2e(*argv, "--version")
    status.success?
  rescue Errno::ENOENT
    false
  end

  def browser_installed?
    return @browser_installed if defined?(@browser_installed)

    executable = cli_executable
    return @browser_installed = false if executable.nil?

    out, status = Open3.capture2e(*executable.shellsplit, "install", "--dry-run", "chromium")
    return @browser_installed = false unless status.success?

    locations = out.lines.filter_map do |line|
      next unless line.include?("Install location:")

      line.split(":", 2).last&.strip
    end
    @browser_installed = locations.any? { |path| browser_tree?(path) }
  rescue Errno::ENOENT
    @browser_installed = false
  end

  def browser_tree?(path)
    return false if path.to_s.empty?
    return false unless File.directory?(path)

    Dir.children(path).any?
  rescue Errno::ENOENT, Errno::EACCES
    false
  end
end
