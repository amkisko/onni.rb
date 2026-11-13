# frozen_string_literal: true

require "generators/onni/stats_rename_generator"

module Onni
  module Generators
    class ShownStatsGenerator < StatsRenameGenerator
      source_root File.expand_path("templates", __dir__)

      remove_task :rename_stats_columns

      def rename_shown_count
        migration_template "rename_onni_shown_count.rb.tt",
          "db/migrate/rename_onni_shown_count.rb"
      end
    end
  end
end
