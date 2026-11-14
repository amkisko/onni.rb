# frozen_string_literal: true

# Rails 7.2 SQLite cannot read boolean DEFAULT TRUE/FALSE written by Rails 8.
# Sequential appraisal runs must not reuse another adapter's identity tables.
module SqliteIdentitySchema
  IDENTITY_TABLES = %w[
    device_authorization_access_tokens
    device_authorization_grants
    device_authorization_clients
    admin_users
  ].freeze

  module_function

  def boolean_defaults_readable?(connection)
    return true unless connection.table_exists?(:admin_users)

    active = connection.columns(:admin_users).find { |column| column.name == "active" }
    !active.nil? && !active.default.nil?
  end

  def drop_identity_tables!(connection)
    IDENTITY_TABLES.each { |name| connection.drop_table(name, if_exists: true) }
  end

  def ensure!(connection, schema_path:)
    drop_identity_tables!(connection) unless boolean_defaults_readable?(connection)

    return if connection.table_exists?(:onni_features) && connection.table_exists?(:device_authorization_clients)

    ActiveRecord::Schema.verbose = false
    load schema_path.to_s
    AdminUser.reset_column_information if defined?(AdminUser)
    DeviceAuthorizationClient.reset_column_information if defined?(DeviceAuthorizationClient)
  end
end
