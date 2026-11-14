# frozen_string_literal: true

ActiveAdmin::DeviceAuthorization.configure do |config|
  config.scopes = %w[onni:read onni:write]
  config.default_scopes = ["onni:read"]
  config.verification_base_url = "https://onni.rails.fi"
  config.current_resource_owner = -> { nil }
  config.register_active_admin_page = false
  config.rate_limit_device_authorization = ->(_) { true }
  config.rate_limit_token = ->(_) { true }
end
