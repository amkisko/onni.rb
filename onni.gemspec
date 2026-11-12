# frozen_string_literal: true

require_relative "lib/onni/version"

Gem::Specification.new do |spec|
  spec.name = "onni"
  spec.version = Onni::VERSION
  spec.authors = ["Andrei Makarov"]
  spec.email = ["contact@kiskolabs.com"]

  spec.summary = "Feature flags, A/B variants, and hit stats for Ruby apps"
  spec.description = <<~TEXT
    Feature-flag and experiment core for any Ruby app: YAML registry, runtime hot
    switches, actor and audience-group targeting, percentage / A/B assignment, and
    hit stats for analysis. Not an authorization system. Optional ActiveRecord
    adapter and pluggable ActiveAdmin dashboard. Includes a pluggable migrator
    for importing gates from another feature-flag library.
  TEXT
  spec.license = "MIT"
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 3.4.0"

  repository_url = "https://github.com/amkisko/onni.rb"

  spec.homepage = repository_url
  spec.metadata = {
    "homepage_uri" => repository_url,
    "source_code_uri" => "#{repository_url}/tree/main",
    "changelog_uri" => "#{repository_url}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{repository_url}/issues",
    "documentation_uri" => "#{repository_url}#readme",
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    %w[
      CHANGELOG.md
      CODE_OF_CONDUCT.md
      CONTRIBUTING.md
      GOVERNANCE.md
      LICENSE.md
      README.md
      SECURITY.md
      onni.gemspec
    ].select { |path| File.file?(path) } +
      Dir["{app,config,lib,sig}/**/*"]
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.2.3.2"

  spec.add_development_dependency "activeadmin", ">= 4.0.0.beta23", "< 5"
  spec.add_development_dependency "appraisal", "~> 2"
  spec.add_development_dependency "bundler", ">= 2"
  spec.add_development_dependency "bundler-audit", "~> 0.9"
  spec.add_development_dependency "importmap-rails"
  spec.add_development_dependency "polyrun", ">= 3.0.0"
  spec.add_development_dependency "rails", ">= 7.2.3.2"
  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "rbs", "~> 4"
  spec.add_development_dependency "rspec", "~> 3"
  spec.add_development_dependency "rspec-rails", ">= 6"
  spec.add_development_dependency "sqlite3", ">= 2.10.2"
  spec.add_development_dependency "rubocop-rspec", "~> 3.8"
  spec.add_development_dependency "rubocop-thread_safety", "~> 0.7"
  spec.add_development_dependency "standard", "~> 1.52"
  spec.add_development_dependency "standard-custom", "~> 1.0"
  spec.add_development_dependency "standard-performance", "~> 1.8"
  spec.add_development_dependency "standard-rspec", "~> 0.3"
end
