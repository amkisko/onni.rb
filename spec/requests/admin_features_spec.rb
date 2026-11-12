# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveAdmin Features page", type: :request do
  it "renders the features index with YAML-known flags" do
    get admin_features_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("demo")
    expect(response.body).to include("search_v2")
    expect(response.body).not_to include("not an authorization system")
    expect(response.body).not_to include("Enable Disable")
  end

  it "does not record hit stats when rendering the index" do
    Onni.enable(:demo)
    Onni::StatBucket.delete_all

    get admin_features_path

    expect(response).to have_http_status(:ok)
    expect(Onni::StatBucket.count).to eq(0)
  end

  it "enables a flag through the page action and persists ActiveRecord gates" do
    expect(Onni.enabled?(:demo)).to be(false)

    post admin_features_enable_path(key: "demo")

    expect(response).to redirect_to(admin_features_path)
    expect(Onni.enabled?(:demo)).to be(true)
    expect(Onni::Gate.where(feature_key: "demo", key: "boolean", value: "true")).to exist
  end

  it "shows a flag detail page with stats after evaluations" do
    Onni.enable(:demo)
    Onni.enabled?(:demo)
    Onni.disable(:demo)
    Onni.enabled?(:demo)

    get admin_features_feature_path(key: "demo")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("demo")
    expect(response.body).to include("Hits")
    expect(response.body).to include("Sample rate")
    expect(response.body).to include(Onni.configuration.stats_sample_rate.to_s)
  end

  it "forbids page actions when admin_authorized fails" do
    Onni.configuration.admin_authorized = -> { false }

    get admin_features_path

    expect(response).to have_http_status(:forbidden)
  ensure
    Onni.configuration.admin_authorized = -> { true }
  end

  it "disables a flag through the page action" do
    Onni.enable(:demo)

    post admin_features_disable_path(key: "demo")

    expect(response).to redirect_to(admin_features_path)
    expect(Onni.enabled?(:demo)).to be(false)
  end

  it "updates percentage, variants, and group gates from the feature form" do
    Onni.register_group(:staff) { |_actor, _| true }

    post admin_features_update_feature_path(
      key: "demo",
      percentage: "40",
      variants: {control: "30", treatment: "70"},
      group_name: "staff",
      group_action: "enable"
    )

    expect(response).to redirect_to(admin_features_feature_path(key: "demo"))
    gates = Onni.adapter.gates_for("demo")
    expect(gates).to include(
      hash_including("key" => "percentage_of_actors", "value" => "40"),
      hash_including("key" => "groups", "value" => "staff")
    )
    variants_gate = gates.find { |gate| gate["key"] == "variants" }
    expect(JSON.parse(variants_gate.fetch("value"))).to include("control" => 30, "treatment" => 70)

    post admin_features_update_feature_path(
      key: "demo",
      group_name: "staff",
      group_action: "disable"
    )

    expect(Onni.adapter.gates_for("demo")).not_to include(hash_including("key" => "groups", "value" => "staff"))
  end

  it "shows one enable or disable action per flag and relative expiry" do
    Onni.enable(:demo)

    get admin_features_path

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    demo_row = document.at_css("a[href*=\"key=demo\"]")&.ancestors("tr")&.first
    search_row = document.at_css("a[href*=\"key=search_v2\"]")&.ancestors("tr")&.first
    expect(demo_row.at_css("button[type=submit]").text).to eq("Disable")
    expect(demo_row.at_css("button[type=submit]").text).not_to eq("Enable")
    expect(search_row.at_css("button[type=submit]").text).to eq("Enable")
    expires = demo_row.at_css("[data-onni-expires]")
    expect(expires["title"]).to eq("2099-01-01")
    expect(expires.text).to match(/\d+ years?/)
  end
end
