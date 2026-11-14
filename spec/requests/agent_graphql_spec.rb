# frozen_string_literal: true

require "rails_helper"
require_relative "../support/agent_access"

RSpec.describe "Device-authorized Onni GraphQL", type: :request do
  include_context "with device-authorized Onni"

  it "discovers typed Onni queries and commands after device consent and token exchange" do
    data = graphql("{ __schema { queryType { fields { name } } mutationType { fields { name } } } }")
    expect(response).to have_http_status(:ok)
    expect(data["errors"]).to be_nil
    queries = data.dig("data", "__schema", "queryType", "fields").map { |field| field["name"] }
    commands = data.dig("data", "__schema", "mutationType", "fields")&.map { |field| field["name"] }
    expect(queries).to include("onni")
    expect(commands).to include("onni_ready", "onni_park", "onni_observe")
  end

  it "reads catalogue metadata without evaluating or counting the feature" do
    data = graphql('{ onni { feature(name: "demo") { name power description type conditions raise_on_expiration signals { key level threshold } } } }')
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "onni", "feature", "name")).to eq("demo")
    expect(data.dig("data", "onni", "feature", "power")).to eq("PENDING")
    expect(data.dig("data", "onni", "feature", "type")).to eq("experiment")
    expect(data.dig("data", "onni", "feature", "conditions")).to eq([])
    expect(data.dig("data", "onni", "feature", "raise_on_expiration")).to be(false)
    expect(Onni::Stats.for(:demo)).to eq([])
  end

  it "readies and parks through the same domain commands as Ruby and ActiveAdmin" do
    data = graphql('mutation { onni_ready(name: "demo") { name power } }')
    expect(data["errors"]).to be_nil
    expect(Onni.ready?(:demo)).to be(true)
    data = graphql('mutation { onni_park(name: "demo", reason: "operator") { power } }')
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "onni_park", "power")).to eq("PARKED")
    expect(Onni.parked?(:demo)).to be(true)
  end

  it "authenticates before returning introspection" do
    graphql("{ __schema { queryType { name } } }", token: nil)
    expect(response).to have_http_status(:unauthorized)
    expect(response.body).to be_empty
  end
end
