# frozen_string_literal: true

# Playwright driver (browser, headless, CLI path, timeout).
# Name must not be :playwright — Rails SystemTesting replaces that registration
# with `npx playwright` (often a mismatched Chromium revision).
# System specs skip when PlaywrightEnv.cli_available? is false (rails_helper).
require "shellwords"

Capybara.save_path = ENV.fetch("CAPYBARA_ARTIFACTS", "log/capybara")
Capybara.default_max_wait_time = ENV.fetch("CAPYBARA_MAX_WAIT", "10").to_i
Capybara.server = :puma, {Silent: true}
# Loopback is in dummy config.hosts; request specs use host! "onni.rails.fi".
Capybara.server_host = ENV.fetch("CAPYBARA_SERVER_HOST", "127.0.0.1")

headless = ENV["HEADFUL"].blank? || ENV["CI"].present?

Capybara.register_driver :railsfi do |app|
  options = {
    browser_type: ENV.fetch("BROWSER", "chromium").to_sym,
    headless: headless,
    playwright_cli_executable_path: PlaywrightEnv.cli_executable || "npx playwright-core"
  }
  Capybara::Playwright::Driver.new(app, **options)
end

Capybara.default_driver = Capybara.javascript_driver = :railsfi
Capybara.app = Rails.application
