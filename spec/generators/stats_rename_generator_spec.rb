# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/active_record"
require_relative "../../lib/generators/onni/stats_rename_generator"

RSpec.describe Onni::Generators::StatsRenameGenerator do
  it "generates a reversible rename that preserves counts and indexes" do
    stub_const("OnniMigrationDatabase", Class.new(ActiveRecord::Base) { self.abstract_class = true })
    OnniMigrationDatabase.establish_connection(adapter: "sqlite3", database: ":memory:")
    stub_const("RenameOnniStatsCounts", Class.new(ActiveRecord::Migration[ActiveRecord::Migration.current_version]))
    connection = OnniMigrationDatabase.connection
    connection.create_table(:onni_feature_stat_buckets) do |table|
      table.string :feature_key
      table.bigint :enabled_hits, null: false, default: 0
      table.bigint :disabled_hits, null: false, default: 0
    end
    connection.add_index(:onni_feature_stat_buckets, :feature_key, unique: true)
    connection.execute("INSERT INTO onni_feature_stat_buckets (feature_key, enabled_hits, disabled_hits) VALUES ('demo', 7, 3)")

    Dir.mktmpdir("onni-stats-rename") do |directory|
      described_class.new([], {quiet: true}, destination_root: directory).invoke_all
      load Dir[File.join(directory, "db/migrate/*rename_onni_stats_counts.rb")].fetch(0)
      migration = RenameOnniStatsCounts.new
      migration.exec_migration(connection, :up)
      expect(connection.select_one("SELECT shown_count, skip_count FROM onni_feature_stat_buckets")).to eq("shown_count" => 7, "skip_count" => 3)
      expect(connection.indexes(:onni_feature_stat_buckets).first.unique).to be(true)
      migration.exec_migration(connection, :down)
      expect(connection.select_one("SELECT enabled_hits, disabled_hits FROM onni_feature_stat_buckets")).to eq("enabled_hits" => 7, "disabled_hits" => 3)
    end
  ensure
    OnniMigrationDatabase.connection_pool.disconnect! if defined?(OnniMigrationDatabase)
  end
end
