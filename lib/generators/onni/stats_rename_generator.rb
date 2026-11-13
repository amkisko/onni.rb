# frozen_string_literal: true

require "generators/onni/install_generator"

module Onni
  module Generators
    class StatsRenameGenerator < InstallGenerator
      source_root File.expand_path("templates", __dir__)

      remove_task :copy_migration
      remove_task :create_features_yml
      remove_task :create_initializer

      def rename_stats_columns
        migration_template "rename_onni_stats_counts.rb.tt",
          "db/migrate/rename_onni_stats_counts.rb"
      end
    end
  end
end
