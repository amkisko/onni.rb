# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../support/isolated_ruby"

RSpec.describe "Onni standard-library core" do
  include IsolatedRuby

  it "evaluates, assigns, imports, records and purges without framework requires or ambient Rails hooks" do
    Tempfile.create(["onni-standalone", ".yml"]) do |file|
      file.write(<<~YAML)
        search_v2:
          type: experiment
          everyone: true
          expires_at: "2099-01-01"
          variants:
            control: 100
      YAML
      file.flush
      result = isolated_ruby(<<~RUBY, file.path, coverage_name: "standalone")
        module FrameworkRequireGuard
          def require(name)
            if %w[active_support active_record activeadmin rails].include?(name.split("/").first)
              raise LoadError, "Framework required by core: " + name
            end
            super
          end
        end
        Kernel.prepend(FrameworkRequireGuard)
        module Rails
          class Engine
            def self.inherited(*)
              raise "Core initialized an ambient Rails engine"
            end
          end
          def self.logger
            raise "Core discovered an ambient Rails logger"
          end
        end
        require "onni"
        Onni.configuration.features_path = ARGV.fetch(0)
        Onni.ready!(:search_v2)
        actor = Struct.new(:feature_actor_id).new("fixture-actor")
        variant = Onni.variant(:search_v2, actor)
        flag = Onni[:search_v2]
        summary = flag.expires_summary(now: Time.utc(2026, 11, 12))
        source = Onni::Migrator::Snapshot.new(feature_keys: ["search_v2"], gates: [])
        imported = Onni.migrate!(source)
        count = Onni::Stats.for(:search_v2).sum { |row| row.fetch("shown_count") }
        Onni.configuration.stats_retention = 0
        purged = Onni.purge_stats!.fetch(:deleted)
        unknown = begin
          Onni.ready!(:unknown_feature)
        rescue KeyError
          true
        end
        admin_setting = Onni.configuration.respond_to?(:admin_authorized)
        Onni.configuration.adapter = :active_record
        Onni.reset_adapter!
        persistence = begin
          Onni.adapter
          true
        rescue ArgumentError
          false
        end
        require "json"
        puts JSON.generate(variant: variant, expires: flag.expires_full, summary: summary,
          imported: imported.fetch(:features), count: count, purged: purged, unknown: unknown,
          admin_setting: admin_setting, persistence: persistence,
          runtime_dependencies: Gem.loaded_specs.fetch("onni").runtime_dependencies.map(&:name))
      RUBY
      expect(result).to eq("variant" => "control", "expires" => "2099-01-01", "summary" => "in 72 years",
        "imported" => 1, "count" => 1, "purged" => 1, "unknown" => true,
        "admin_setting" => false, "persistence" => false, "runtime_dependencies" => [])
    end
  end
end
