# frozen_string_literal: true

load File.expand_path("onni_schema.rb", __dir__)

ActiveRecord::Schema.define do
  create_table "admin_users", force: :cascade do |table|
    table.boolean "active", default: true, null: false
    table.boolean "can_write", default: false, null: false
  end

  create_table "device_authorization_clients", force: :cascade do |table|
    table.string "client_id", null: false
    table.boolean "enabled", default: true, null: false
    table.json "allowed_scopes", default: [], null: false
    table.index ["client_id"], unique: true
  end

  create_table "device_authorization_grants", force: :cascade do |table|
    table.references "device_authorization_client", null: false, foreign_key: true
    table.references "admin_user", foreign_key: true
    table.string "device_code_digest", null: false
    table.string "user_code", null: false
    table.string "status", default: "pending", null: false
    table.json "requested_scopes", default: [], null: false
    table.json "granted_scopes", default: [], null: false
    table.datetime "challenge_expires_at", null: false
    table.datetime "last_poll_at"
    table.integer "poll_interval_seconds"
    table.integer "absolute_ttl_seconds"
    table.index ["user_code"], unique: true
    table.index ["device_authorization_client_id", "device_code_digest"], unique: true, name: "index_device_grant_digest"
  end

  create_table "device_authorization_access_tokens", force: :cascade do |table|
    table.references "device_authorization_client", null: false, foreign_key: true
    table.references "admin_user", null: false, foreign_key: true
    table.references "device_authorization_grant", null: false, foreign_key: true, index: {unique: true}
    table.string "token_digest", null: false
    table.json "scopes", default: [], null: false
    table.datetime "absolute_expires_at", null: false
    table.datetime "last_used_at", null: false
    table.datetime "revoked_at"
    table.index ["token_digest"], unique: true
  end

end
