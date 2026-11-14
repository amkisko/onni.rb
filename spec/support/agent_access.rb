# frozen_string_literal: true

module AgentAccess
  Principal = Data.define(:owner, :scopes)

  module BearerAuthentication
    def authenticate_onni_agent!
      return if @onni_agent

      plaintext, = ActionController::HttpAuthentication::Token.token_and_options(request)
      return head(:unauthorized) if plaintext.blank?

      config = ActiveAdmin::DeviceAuthorization.config
      token = DeviceAuthorizationAccessToken.joins(:device_authorization_client)
        .merge(DeviceAuthorizationClient.enabled.where(client_id: "onni-agent"))
        .find_by(token_digest: config.digest(plaintext))
      return head(:unauthorized) unless token&.admin_user&.active_for_authentication?

      expired = ActiveAdmin::DeviceAuthorization::AccessTokenExpiry.new.expired?(
        absolute_expires_at: token.absolute_expires_at, last_used_at: token.last_used_at, revoked_at: token.revoked_at
      )
      return head(:unauthorized) if expired
      return head(:forbidden) unless token.scopes.include?("onni:read")

      token.update!(last_used_at: Time.current)
      @onni_agent = Principal.new(owner: token.admin_user, scopes: token.scopes)
    end

    def current_onni_agent
      @onni_agent
    end
  end

  class Authorization < ActiveAdmin::AuthorizationAdapter
    def authorized?(action, _subject = nil)
      action == :read || user&.owner&.can_write == true
    end
  end

  def with_agent_namespace
    namespace = ActiveAdmin.application.namespaces[:admin]
    keys = %i[graphql authentication_method current_user_method authorization_adapter graphql_visibility
      graphql_capabilities graphql_configure_schema]
    previous = keys.to_h { |key| [key, namespace.public_send(key)] }
    namespace.graphql = true
    namespace.authentication_method = :authenticate_onni_agent!
    namespace.current_user_method = :current_onni_agent
    namespace.authorization_adapter = Authorization
    namespace.graphql_visibility = {preload: false}
    namespace.graphql_capabilities = ->(context) { context[:current_user]&.scopes }
    namespace.graphql_configure_schema = ->(schema) { Onni::Admin::GraphQL.install!(schema) }
    ActiveAdmin::GraphQL.clear_schema_cache!
    Rails.application.reload_routes!
    yield
  ensure
    previous.each { |key, value| namespace.public_send("#{key}=", value) }
    ActiveAdmin::GraphQL.clear_schema_cache!
    Rails.application.reload_routes!
  end

  def issue_agent_token(owner:, scopes: %w[onni:read onni:write])
    client = DeviceAuthorizationClient.find_or_create_by!(client_id: "onni-agent") do |record|
      record.allowed_scopes = %w[onni:read onni:write]
    end
    config = ActiveAdmin::DeviceAuthorization.config
    previous_owner = config.current_resource_owner
    config.current_resource_owner = -> { owner }
    post "/admin/oauth/device_authorization", params: {client_id: client.client_id, scope: scopes.join(" ")}
    raise "Challenge failed: #{response.status}" unless response.status == 200

    challenge = response.parsed_body
    post "/admin/device_auth/#{challenge.fetch("user_code")}/approve", params: {scopes: scopes}
    raise "Consent failed: #{response.status}" unless response.redirect?

    @device_code = challenge.fetch("device_code")
    post "/admin/oauth/token", params: {client_id: client.client_id, device_code: @device_code,
                                        grant_type: ActiveAdmin::DeviceAuthorization::TokenExchange::GRANT_TYPE}
    raise "Token exchange failed: #{response.status}" unless response.status == 200

    response.parsed_body.fetch("access_token")
  ensure
    config.current_resource_owner = previous_owner
  end

  def graphql(query, variables: {}, token: @access_token)
    headers = token ? {"Authorization" => "Bearer #{token}"} : {}
    post "/admin/graphql", params: {query: query, variables: variables}, headers: headers, as: :json
    response.parsed_body unless response.body.empty?
  end
end

ActiveAdmin::GraphqlController.include(AgentAccess::BearerAuthentication)
ActiveAdmin::GraphqlController.prepend_before_action :authenticate_onni_agent!,
  if: -> { active_admin_namespace.authentication_method == :authenticate_onni_agent! }
ActiveAdmin::GraphqlController.skip_forgery_protection if: -> { current_onni_agent.present? }

RSpec.shared_context "with device-authorized Onni" do
  include AgentAccess

  let(:owner) { AdminUser.create!(can_write: true) }
  let(:token_record) do
    DeviceAuthorizationAccessToken.find_by!(token_digest: ActiveAdmin::DeviceAuthorization.config.digest(@access_token))
  end

  around { |example| with_agent_namespace { example.run } }
  before { @access_token = issue_agent_token(owner: owner) }
end
