# frozen_string_literal: true

class DeviceAuthorizationGrant < ApplicationRecord
  belongs_to :device_authorization_client
  belongs_to :admin_user, optional: true
  has_one :device_authorization_access_token
  validates :status, inclusion: {in: %w[pending approved denied expired]}

  def pending?
    status == "pending"
  end

  def mark_expired_if_needed!
    return false unless %w[pending approved].include?(status) && challenge_expires_at <= Time.current

    update!(status: "expired")
    true
  end
end
