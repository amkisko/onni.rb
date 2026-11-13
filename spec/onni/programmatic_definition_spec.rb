# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/isolated_ruby"

RSpec.describe "Programmatic feature definitions" do
  include IsolatedRuby

  it "defines without YAML, retains strict misses, and survives registry and adapter resets" do
    result = isolated_ruby(<<~RUBY, coverage_name: "runtime-definitions")
      require "onni"
      Onni.configuration.features_path = nil
      Onni.define!(:new_checkout, description: "Checkout experiment", expires_at: "2099-01-01",
        everyone: true, type: "experiment", variants: {treatment: 100})
      actor = Struct.new(:id).new(7)
      pending = Onni.pending?(:new_checkout) && !Onni.visible?(:new_checkout, actor)
      Onni.ready!(:new_checkout)
      assigned = Onni.variant(:new_checkout, actor)
      Onni::Registry.reload!
      retained = Onni.visible?(:new_checkout, actor, record_stats: false)
      Onni.reset_adapter!
      reset = Onni.pending?(:new_checkout) && Onni[:new_checkout].exist?
      unknown = begin
        Onni.ready!(:missing)
        false
      rescue KeyError
        !Onni.visible?(:missing)
      end
      puts JSON.generate(pending: pending, assigned: assigned, retained: retained,
        reset: reset, unknown: unknown, description: Onni[:new_checkout].description)
    RUBY
    expect(result).to eq("pending" => true, "assigned" => "treatment", "retained" => true,
      "reset" => true, "unknown" => true, "description" => "Checkout experiment")
  end

  it "requires documentation, validates settings, and copies caller-owned data before publication" do
    result = isolated_ruby(<<~RUBY, coverage_name: "runtime-definition-validation")
      require "onni"
      Onni.configuration.features_path = nil
      cyclic = {}
      cyclic["enabled"] = cyclic
      rejected = [{description: "", expires_at: "2099-01-01"},
        {description: "Experiment", expires_at: "invalid"},
        {description: "Experiment", expires_at: ""},
        {description: "Experiment", expires_at: "2099-01-01", level: 101},
        {description: "Experiment", expires_at: "2099-01-01", unknown: true},
        {description: "Experiment", expires_at: "2099-01-01", stats: cyclic}].count do |definition|
        begin
          Onni.define!(:invalid_feature, **definition)
          false
        rescue ArgumentError
          !Onni[:invalid_feature].exist?
        end
      end
      groups = ["beta_testers"]
      Onni.define!(:new_checkout, description: "Checkout experiment", expires_at: "2099-01-01",
        groups: groups, stats: {enabled: false})
      groups.clear
      copied = Onni[:new_checkout].groups == ["beta_testers"]
      Onni.define!(:new_checkout, description: "Revised experiment", expires_at: "2099-02-01", everyone: true)
      revised = Onni[:new_checkout].description == "Revised experiment"
      puts JSON.generate(rejected: rejected, copied: copied, revised: revised)
    RUBY
    expect(result).to eq("rejected" => 6, "copied" => true, "revised" => true)
  end

  it "refuses to shadow a YAML-owned feature" do
    Tempfile.create(["onni-registry", ".yml"]) do |file|
      file.write("new_checkout:\n  description: Shared flag\n  expires_at: '2099-01-01'\n  everyone: true\n")
      file.flush
      result = isolated_ruby(<<~RUBY, file.path, coverage_name: "runtime-definition-shadow")
        require "onni"
        Onni.configuration.features_path = ARGV.fetch(0)
        rejected = begin
          Onni.define!(:new_checkout, description: "Shadow", expires_at: "2099-01-01")
          false
        rescue ArgumentError
          true
        end
        puts JSON.generate(rejected: rejected, description: Onni[:new_checkout].description)
      RUBY
      expect(result).to eq("rejected" => true, "description" => "Shared flag")
    end
  end

  it "replaces expiration while retaining stored runtime settings and historical counts" do
    result = isolated_ruby(<<~RUBY, coverage_name: "runtime-definition-replacement")
      require "onni"
      Onni.configuration.features_path = nil
      Onni.define!(:new_checkout, description: "Expired experiment", expires_at: "2000-01-01", everyone: true)
      Onni.ready!(:new_checkout)
      expired = !Onni.visible?(:new_checkout)
      Onni.filters!(:new_checkout, everyone: false)
      Onni.stats!(:new_checkout, enabled: false)
      Onni.define!(:new_checkout, description: "Renewed experiment", expires_at: "2099-01-01", everyone: true)
      retained = Onni.ready?(:new_checkout) && !Onni.visible?(:new_checkout) &&
        !Onni[:new_checkout].stats_settings.fetch("enabled")
      Onni.filters!(:new_checkout, everyone: true)
      renewed = Onni.visible?(:new_checkout)
      counts = Onni::Stats.for(:new_checkout).sum { |row| row["skip_count"] }
      puts JSON.generate(expired: expired, retained: retained, renewed: renewed, skips: counts)
    RUBY
    expect(result).to eq("expired" => true, "retained" => true, "renewed" => true, "skips" => 1)
  end

  it "rejects a collision introduced by reloading YAML" do
    Tempfile.create(["onni-registry", ".yml"]) do |file|
      file.write("{}\n")
      file.flush
      result = isolated_ruby(<<~RUBY, file.path, coverage_name: "runtime-definition-reload-collision")
        require "onni"
        Onni.configuration.features_path = ARGV.fetch(0)
        Onni.define!(:new_checkout, description: "Runtime flag", expires_at: "2099-01-01")
        File.write(ARGV.fetch(0), "new_checkout:\\n  everyone: true\\n")
        rejected = begin
          Onni::Registry.reload!
          false
        rescue ArgumentError
          true
        end
        File.write(ARGV.fetch(0), "{}\\n")
        Onni::Registry.reload!
        puts JSON.generate(rejected: rejected, description: Onni[:new_checkout].description)
      RUBY
      expect(result).to eq("rejected" => true, "description" => "Runtime flag")
    end
  end
end
