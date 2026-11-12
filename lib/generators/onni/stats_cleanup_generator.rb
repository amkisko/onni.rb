# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Onni
  module Generators
    class StatsCleanupGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        next_number = Time.now.utc.strftime("%Y%m%d%H%M%S")
        if Dir.exist?(dirname)
          while Dir.children(dirname).any? { |name| name.start_with?(next_number) }
            next_number = (next_number.to_i + 1).to_s
          end
        end
        next_number
      end

      def create_job
        template "purge_stats_job.rb.tt", "app/jobs/onni_purge_stats_job.rb"
      end

      def create_period_start_index_migration
        migration_template "add_onni_stats_period_start_index.rb.tt",
          "db/migrate/add_onni_stats_period_start_index.rb"
      end

      def show_schedule_notes
        say <<~MSG

          Onni stats cleanup installed.

          1. Migrate: bin/rails db:migrate
          2. Set retention in config/initializers/onni.rb:
               config.stats_retention = 90.days
          3. Schedule the job daily (host job backend or cron), for example:
               OnniPurgeStatsJob.perform_later
          4. One-shot console drain (no queue):
               Onni.purge_stats!(older_than: 90.days.ago)

          See README "Stats growth and cleanup" for >1GB / >10M row guidance.
        MSG
      end
    end
  end
end
