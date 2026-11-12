# frozen_string_literal: true

return unless defined?(Rails::Engine)

module Onni
  class Engine < ::Rails::Engine
    engine_name "onni"

    initializer "onni.configure", before: :load_config_initializers do
      Onni.configure do |config|
        config.features_path = Rails.root.join("config/features.yml")
        config.cache = Rails.cache
        config.adapter = Rails.env.test? ? :memory : :active_record
      end
    end

    # Rails engines eager-load every app/* directory. ActiveAdmin DSL files are
    # not Zeitwerk constants; ActiveAdmin loads them via load_paths.
    initializer "onni.configure_zeitwerk" do
      Rails.autoloaders.main.ignore(root.join("app/admin"))
    end

    initializer "onni.load_active_admin" do
      next unless defined?(ActiveAdmin)

      path = root.join("app/admin").to_s
      ActiveSupport.on_load(:after_initialize) do
        ActiveAdmin.application.load_paths << path unless ActiveAdmin.application.load_paths.include?(path)
      end
    end

    initializer "onni.i18n" do
      I18n.load_path += Dir[root.join("config/locales/*.yml")]
    end

    config.after_initialize do
      boot_sync_registry!
    end

    def self.boot_sync_registry!
      return unless Rails.env.local?
      return if defined?(Rake) && Rake.application.top_level_tasks.any? { |task| task.start_with?("db:") }
      return if Onni.configuration.adapter == :memory

      Onni.sync_registry!
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      nil
    end
  end
end
