# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/active_record"

RSpec.describe "Transitional shown-count migration" do
  it "renames show_count reversibly without altering skip counts or indexes" do
    require_relative "../../lib/generators/onni/shown_stats_generator"
    stub_const("OnniMigrationDatabase", Class.new(ActiveRecord::Base) { self.abstract_class = true })
    OnniMigrationDatabase.establish_connection(adapter: "sqlite3", database: ":memory:")
    stub_const("RenameOnniShownCount", Class.new(ActiveRecord::Migration[ActiveRecord::Migration.current_version]))
    connection = OnniMigrationDatabase.connection
    connection.create_table(:onni_feature_stat_buckets) do |table|
      table.string :feature_key
      table.bigint :show_count, null: false, default: 0
      table.bigint :skip_count, null: false, default: 0
    end
    connection.add_index(:onni_feature_stat_buckets, :feature_key, unique: true)
    connection.execute("INSERT INTO onni_feature_stat_buckets (feature_key, show_count, skip_count) VALUES ('demo', 7, 3)")

    Dir.mktmpdir("onni-shown-stats") do |directory|
      Onni::Generators::ShownStatsGenerator.new([], {quiet: true}, destination_root: directory).invoke_all
      load Dir[File.join(directory, "db/migrate/*rename_onni_shown_count.rb")].fetch(0)
      migration = RenameOnniShownCount.new
      migration.exec_migration(connection, :up)
      expect(connection.select_one("SELECT shown_count, skip_count FROM onni_feature_stat_buckets")).to eq("shown_count" => 7, "skip_count" => 3)
      expect(connection.indexes(:onni_feature_stat_buckets).first.unique).to be(true)
      migration.exec_migration(connection, :down)
      expect(connection.select_one("SELECT show_count, skip_count FROM onni_feature_stat_buckets")).to eq("show_count" => 7, "skip_count" => 3)
    end
  ensure
    OnniMigrationDatabase.connection_pool.disconnect! if defined?(OnniMigrationDatabase)
  end
end
