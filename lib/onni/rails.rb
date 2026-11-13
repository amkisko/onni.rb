# frozen_string_literal: true

gem "railties", ">= 7.2.3.2"
require "rails"
require "rails/engine"
require "onni"
require "onni/active_support"
require "onni/middleware/request_lifecycle"

module Onni
  class Engine < ::Rails::Engine
    engine_name "onni"

    paths["app"] = []
    paths["app/models"] = []
    paths["app/views"] = []
    paths["config/locales"] = []

    initializer "onni.configure", before: :load_config_initializers do
      Onni.configure do |config|
        config.features_path = Rails.root.join("config/features.yml")
        config.cache = Rails.cache
        config.logger = Rails.logger
      end
    end

    # Always wrap requests so stats_buffer / preload clear via reset_request!.
    # Work stays cheap when buffer and request_preload are off.
    initializer "onni.request_middleware" do |app|
      app.middleware.use Onni::Middleware::RequestLifecycle
    end

    config.after_initialize do
      boot_sync_registry!
    end

    def self.boot_sync_registry!
      return unless Rails.env.local?
      return if defined?(Rake) && Rake.application.top_level_tasks.any? { |task| task.start_with?("db:") }
      return if Onni.configuration.adapter == :memory

      Onni.sync_registry!
    rescue => error
      if defined?(::ActiveRecord::StatementInvalid)
        case error
        when ::ActiveRecord::StatementInvalid, ::ActiveRecord::NoDatabaseError
          return
        end
      end

      raise
    end
  end
end
