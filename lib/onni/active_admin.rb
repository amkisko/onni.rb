# frozen_string_literal: true

gem "activeadmin", ">= 4.0.0.beta23", "< 5"
require "onni/rails"
require "onni/active_record"
require "activeadmin"
require "onni/active_admin_routes"
require "onni/admin/flags_query"

module Onni
  module Admin
    module Configuration
      DEFAULT_AUTHORIZATION = -> { true }.freeze

      attr_writer :admin_authorized

      def admin_authorized
        defined?(@admin_authorized) ? @admin_authorized : DEFAULT_AUTHORIZATION
      end
    end
  end
end

Onni::Configuration.include(Onni::Admin::Configuration)
Onni::Engine.paths.add "app/models", eager_load: true
Onni::Engine.paths["app/views"] << "app/views"
Onni::Engine.paths["config/locales"] << "config/locales"

Onni::Engine.initializer "onni.configure_zeitwerk" do
  Rails.autoloaders.main.ignore(Onni::Engine.root.join("app/admin"))
end

Onni::Engine.initializer "onni.load_active_admin" do
  path = Onni::Engine.root.join("app/admin").to_s
  ActiveSupport.on_load(:after_initialize) do
    ActiveAdmin.application.load_paths << path unless ActiveAdmin.application.load_paths.include?(path)
  end
end

Onni::Engine.initializer "onni.i18n" do
  I18n.load_path += Dir[Onni::Engine.root.join("config/locales/*.yml")]
end
