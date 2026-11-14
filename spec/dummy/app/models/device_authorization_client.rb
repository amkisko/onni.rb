# frozen_string_literal: true

class DeviceAuthorizationClient < ApplicationRecord
  scope :enabled, -> { where(enabled: true) }
  has_many :device_authorization_access_tokens

  def allows_scopes?(scopes)
    (scopes - allowed_scopes).empty?
  end
end
