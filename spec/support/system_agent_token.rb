# frozen_string_literal: true

# Mint a disposable device-auth bearer for browser GraphQL e2e without request helpers.
module SystemAgentToken
  module_function

  def mint(owner:, scopes: %w[onni:read onni:write])
    client = DeviceAuthorizationClient.find_or_create_by!(client_id: "onni-agent") do |record|
      record.enabled = true
      record.allowed_scopes = %w[onni:read onni:write]
    end
    config = ActiveAdmin::DeviceAuthorization.config
    device_code = SecureRandom.hex(16)
    grant = DeviceAuthorizationGrant.create!(
      device_authorization_client: client,
      admin_user: owner,
      device_code_digest: config.digest(device_code),
      user_code: SecureRandom.hex(4),
      status: "approved",
      requested_scopes: scopes,
      granted_scopes: scopes,
      challenge_expires_at: 10.minutes.from_now
    )
    plaintext = SecureRandom.hex(32)
    DeviceAuthorizationAccessToken.create!(
      device_authorization_client: client,
      device_authorization_grant: grant,
      admin_user: owner,
      token_digest: config.digest(plaintext),
      scopes: scopes,
      absolute_expires_at: 1.hour.from_now,
      last_used_at: Time.current
    )
    plaintext
  end
end
