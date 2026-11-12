# frozen_string_literal: true

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.action_controller.raise_on_missing_callback_actions = true
  config.active_support.deprecation = :stderr
  config.active_record.maintain_test_schema = false
end
