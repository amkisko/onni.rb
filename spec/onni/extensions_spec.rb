# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../support/isolated_ruby"

RSpec.describe "Onni opt-in extensions" do
  include IsolatedRuby

  it "delivers notifications only through the explicitly selected ActiveSupport extension" do
    result = isolated_ruby(<<~RUBY, coverage_name: "active-support-extension")
      require "onni/active_support"
      events = []
      subscription = ActiveSupport::Notifications.subscribe("fixture.onni") do |*arguments|
        events << arguments.last.fetch(:result)
      end
      value = Onni::Instrumenter.instrument("fixture") { |payload| payload[:result] = "ok" }
      ActiveSupport::Notifications.unsubscribe(subscription)
      require "json"
      puts JSON.generate(value: value, events: events)
    RUBY
    expect(result).to eq("value" => "ok", "events" => ["ok"])
  end

  it "persists gates and counters through ActiveRecord without loading Rails" do
    Dir.mktmpdir("onni-active-record") do |directory|
      path = File.join(directory, "features.yml")
      File.write(path, "new_checkout:\n  everyone: true\n")
      result = isolated_ruby(<<~RUBY, path, coverage_name: "active-record-extension")
        module RailsRequireGuard
          def require(name)
            raise LoadError, "Unexpected framework " + name if %w[rails activeadmin].include?(name.split("/").first)
            super
          end
        end
        Kernel.prepend(RailsRequireGuard)
        require "onni/active_record"
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        ActiveRecord::Schema.verbose = false
        load File.join(ENV.fetch("ONNI_SPEC_ROOT"), "spec/dummy/db/schema.rb")
        Onni.configuration.features_path = ARGV.fetch(0)
        Onni.configuration.adapter = :active_record
        Onni.ready!(:new_checkout)
        visible = Onni.visible?(:new_checkout)
        count = Onni::StatBucket.sum(:shown_count)
        require "json"
        puts JSON.generate(visible: visible, count: count, features: Onni::Feature.count)
      RUBY
      expect(result).to eq("visible" => true, "count" => 1, "features" => 1)
    end
  end

  it "initializes Rails integration without loading persistence or admin plugins" do
    Dir.mktmpdir("onni-rails") do |directory|
      FileUtils.mkdir_p(File.join(directory, "config"))
      File.write(File.join(directory, "config/features.yml"), "new_checkout:\n  everyone: true\n")
      result = isolated_ruby(<<~RUBY, directory, coverage_name: "rails-extension")
        ENV["RAILS_ENV"] = "test"
        # Alias before Zeitwerk loads; prepend+super breaks once Zeitwerk redefines require.
        module Kernel
          alias_method :onni_extensions_original_require, :require
          def require(name)
            feature = name.is_a?(String) ? name : name.to_s
            if %w[active_record activeadmin].include?(feature.split("/").first)
              raise LoadError, "Unexpected persistence/admin " + feature
            end
            onni_extensions_original_require(name)
          end
        end
        require "onni/rails"
        application = Class.new(Rails::Application)
        application.config.root = ARGV.fetch(0)
        application.config.eager_load = false
        application.config.secret_key_base = "fixture" * 12
        application.initialize!
        Onni.ready!(:new_checkout)
        require "json"
        puts JSON.generate(visible: Onni.visible?(:new_checkout),
          middleware: application.middleware.include?(Onni::Middleware::RequestLifecycle),
          logger: Onni.configuration.logger.equal?(Rails.logger), adapter: Onni.configuration.adapter)
      RUBY
      expect(result).to eq("visible" => true, "middleware" => true, "logger" => true, "adapter" => "memory")
    end
  end
end
