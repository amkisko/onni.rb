# frozen_string_literal: true

require "rails_helper"
require_relative "../support/agent_access"

RSpec.describe "ActiveAdmin GraphQL in the browser", type: :system do
  include AgentAccess

  around { |example| with_browser_agent_graphql { example.run } }

  it "reads the Onni catalogue over bearer GraphQL from the same origin" do
    owner = AdminUser.create!(active: true, can_write: true)
    token = SystemAgentToken.mint(owner: owner)

    visit admin_features_path
    expect(page).to have_content("Flags")

    payload = page.evaluate_async_script(<<~JS, token)
      const token = arguments[0]
      const done = arguments[arguments.length - 1]
      fetch("/admin/graphql", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer " + token
        },
        body: JSON.stringify({
          query: '{ onni { feature(name: "demo") { name power type } } }'
        })
      }).then(async (response) => {
        const body = await response.json()
        done({status: response.status, body})
      }).catch((error) => done({status: 0, error: String(error)}))
    JS

    expect(payload.fetch("status")).to eq(200)
    expect(payload.dig("body", "errors")).to be_nil
    expect(payload.dig("body", "data", "onni", "feature")).to include(
      "name" => "demo",
      "power" => "PENDING",
      "type" => "experiment"
    )
  end

  it "rejects GraphQL discovery without a bearer token" do
    visit admin_features_path

    payload = page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      fetch("/admin/graphql", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({query: "{ __typename }"})
      }).then(async (response) => {
        done({status: response.status, body: await response.text()})
      }).catch((error) => done({status: 0, error: String(error)}))
    JS

    expect(payload.fetch("status")).to eq(401)
  end
end
