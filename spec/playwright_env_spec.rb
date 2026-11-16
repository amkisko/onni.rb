# frozen_string_literal: true

require "spec_helper"
require_relative "support/playwright_env"

RSpec.describe PlaywrightEnv do
  before do
    described_class.instance_variables.each { |name| described_class.remove_instance_variable(name) }
  end

  it "skips readiness when the Chromium install tree is empty" do
    allow(described_class).to receive(:detect_executable).and_return("playwright-core")
    allow(Open3).to receive(:capture2e).with("playwright-core", "--version").and_return(["1.0", instance_double(Process::Status, success?: true)])
    allow(Open3).to receive(:capture2e).with("playwright-core", "install", "--dry-run", "chromium").and_return(
      ["Install location:    /tmp/missing-chromium-tree\n", instance_double(Process::Status, success?: true)]
    )
    allow(described_class).to receive(:browser_tree?).with("/tmp/missing-chromium-tree").and_return(false)

    expect(described_class.ready?).to be(false)
    expect(described_class.hint).to include("Chromium is not installed for the browser CLI")
  end
end
