# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Onni
  module Generators
    class InstallGenerator < Rails::Generators::Base
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

      def copy_migration
        migration_template "create_onni_features.rb.tt",
          "db/migrate/create_onni_features.rb"
      end

      def create_features_yml
        template "features.yml.tt", "config/features.yml"
      end

      def create_initializer
        template "initializer.rb.tt", "config/initializers/onni.rb"
      end
    end
  end
end
