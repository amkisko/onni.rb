# frozen_string_literal: true

require "rails_helper"
require_relative "../support/agent_access"

RSpec.describe "Onni GraphQL access boundaries", type: :request do
  include_context "with device-authorized Onni"

  let(:introspection) { "{ __schema { queryType { fields { name } } mutationType { fields { name } } } }" }
  let(:ready) { 'mutation { onni_ready(name: "demo") { power } }' }

  it "keeps capabilities isolated between read and write tokens on the cached schema" do
    reader_token = issue_agent_token(owner: owner, scopes: ["onni:read"])
    writer = graphql(introspection)
    expect(writer.dig("data", "__schema", "mutationType", "fields").map { |field| field["name"] }).to include("onni_ready")
    reader = graphql(introspection, token: reader_token)
    expect(reader["errors"]).to be_nil
    expect(reader.dig("data", "__schema", "mutationType")).to be_nil
    private_input = graphql('{ __type(name: "OnniAudienceInput") { name inputFields { name } } }', token: reader_token)
    expect(private_input.dig("data", "__type")).to be_nil
    data = graphql(ready, token: reader_token)
    expect(data["errors"]).to be_present
    expect(Onni.pending?(:demo)).to be(true)
    graphql(ready)
    expect(Onni.ready?(:demo)).to be(true)
  end

  it "requires the host policy even with write scopes" do
    owner.update!(can_write: false)
    data = graphql(ready)
    expect(data["errors"]).to be_present
    expect(Onni.pending?(:demo)).to be(true)
  end

  it "honors the Onni admin callback for reads and commands" do
    Onni.configuration.admin_authorized = -> { current_active_admin_user.owner.active_for_authentication? }
    expect(graphql('{ onni { feature(name: "demo") { name } } }')["errors"]).to be_nil
    Onni.configuration.admin_authorized = -> { false }
    data = graphql('{ onni { feature(name: "demo") { name } } }')
    expect(data["errors"]).to be_present
    expect(graphql(ready)["errors"]).to be_present
    private_type = graphql('{ __type(name: "OnniFeature") { name } }')
    expect(private_type.dig("data", "__type")).to be_nil
    expect(Onni.pending?(:demo)).to be(true)
  end

  {
    revoked: ->(token) { token.update!(revoked_at: Time.current) },
    absolute_expiry: ->(token) { token.update!(absolute_expires_at: 1.second.ago) },
    idle_expiry: ->(token) { token.update!(last_used_at: 2.hours.ago) },
    disabled_owner: ->(token) { token.admin_user.update!(active: false) },
    disabled_client: ->(token) { token.device_authorization_client.update!(enabled: false) },
    wrong_client: ->(token) { token.device_authorization_client.update!(client_id: "other-agent") }
  }.each do |condition, change|
    it "rejects #{condition} before schema discovery or command execution" do
      change.call(token_record)
      previous_use = token_record.reload.last_used_at
      graphql(introspection)
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to be_empty
      graphql(ready)
      expect(response).to have_http_status(:unauthorized)
      expect(Onni.pending?(:demo)).to be(true)
      expect(token_record.reload.last_used_at).to eq(previous_use)
    end
  end

  it "returns 403 for an authenticated token without read scope" do
    token_record.update!(scopes: ["onni:write"])
    graphql(introspection)
    expect(response).to have_http_status(:forbidden)
  end

  it "does not accept an unknown bearer token" do
    graphql(introspection, token: "invalid-disposable-fixture")
    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts validated bearer requests with CSRF protection enabled and rejects invalid credentials first" do
    previous = ActiveAdmin::GraphqlController.allow_forgery_protection
    ActiveAdmin::GraphqlController.allow_forgery_protection = true
    data = graphql(ready)
    expect(response).to have_http_status(:ok)
    expect(data["errors"]).to be_nil
    expect(Onni.ready?(:demo)).to be(true)
    graphql(introspection, token: "invalid-disposable-fixture")
    expect(response).to have_http_status(:unauthorized)
  ensure
    ActiveAdmin::GraphqlController.allow_forgery_protection = previous
  end

  it "allows a device grant to be redeemed only once" do
    post "/admin/oauth/token", params: {client_id: "onni-agent", device_code: @device_code,
                                        grant_type: ActiveAdmin::DeviceAuthorization::TokenExchange::GRANT_TYPE}
    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.fetch("error")).to eq("invalid_grant")
    expect(DeviceAuthorizationAccessToken.count).to eq(1)
  end
end

RSpec.describe "Onni agent consent boundaries", type: :request do
  include_context "with device-authorized Onni"

  def request_challenge
    post "/admin/oauth/device_authorization", params: {client_id: "onni-agent", scope: "onni:read"}
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  def poll_challenge(challenge)
    post "/admin/oauth/token", params: {client_id: "onni-agent", device_code: challenge.fetch("device_code"),
                                        grant_type: ActiveAdmin::DeviceAuthorization::TokenExchange::GRANT_TYPE}
  end

  it "reports authorization_pending until an authenticated owner grants consent" do
    challenge = request_challenge
    poll_challenge(challenge)
    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.fetch("error")).to eq("authorization_pending")
    post "/admin/device_auth/#{challenge.fetch("user_code")}/approve", params: {scopes: ["onni:read"]}
    expect(response).to have_http_status(:unauthorized)
    expect(DeviceAuthorizationAccessToken.count).to eq(1)
  end

  it "preserves protocol-level rate limiting without issuing a token" do
    challenge = request_challenge
    allow(ActiveAdmin::DeviceAuthorization.config).to receive(:rate_limit_token).and_return(->(_) { false })
    poll_challenge(challenge)
    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body.fetch("error")).to eq("slow_down")
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(DeviceAuthorizationAccessToken.count).to eq(1)
  end
end
