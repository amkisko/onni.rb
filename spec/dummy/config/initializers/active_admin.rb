# frozen_string_literal: true

ActiveAdmin.setup do |config|
  config.authentication_method = false
  config.current_user_method = false
  config.site_title = "Onni Dummy"
  config.logout_link_path = false
end
