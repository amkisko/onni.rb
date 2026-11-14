# frozen_string_literal: true

class DeviceAuthorizationAccessToken < ApplicationRecord
  belongs_to :device_authorization_client
  belongs_to :device_authorization_grant
  belongs_to :admin_user
end
