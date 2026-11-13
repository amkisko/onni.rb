# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveAdmin Features page", type: :request do
  it "renders the Flags index with YAML-known flags, scopes, and filters" do
    get admin_features_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("demo")
    expect(response.body).to include("search_v2")
    expect(response.body).to include("Flags")
    expect(response.body).to include("filters-form")
    expect(response.body).to include("index-button-selected")
    expect(response.body).to include("scopes-count")
    expect(response.body).to include("paginated-collection")
    expect(response.body).not_to include("not an authorization system")
    expect(response.body).not_to include("Enable Disable")
    expect(response.body).not_to include("matching ·")
  end

  it "filters flags by search and pending scope" do
    get admin_features_path, params: {q: "demo", scope: "pending"}

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("demo")
  end

  it "does not record hit stats when rendering the index" do
    Onni.ready!(:demo)
    Onni::StatBucket.delete_all

    get admin_features_path

    expect(response).to have_http_status(:ok)
    expect(Onni::StatBucket.count).to eq(0)
  end

  it "loads status gates once for a large registry" do
    definitions = 50.times.to_h { |index| ["feature_#{index}", {"everyone" => true}] }
    allow(Onni::Registry).to receive(:config).and_return(definitions)
    queries = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*arguments|
      payload = arguments.last
      queries += 1 if payload[:name] == "Onni::Gate Load" && !payload[:cached]
    end
    [false, true].each do |preload|
      Onni.configuration.request_preload = preload
      queries = 0
      get admin_features_path
      expect(response).to have_http_status(:ok)
      expect(queries).to eq(1)
    end
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "readies a flag through the page action and persists ActiveRecord gates" do
    expect(Onni.visible?(:demo)).to be(false)

    post admin_features_ready_path(key: "demo")

    expect(response).to redirect_to(admin_features_path)
    expect(Onni.visible?(:demo)).to be(true)
    expect(Onni::Gate.where(feature_key: "demo", key: "powered", value: "true")).to exist
  end

  it "shows a flag detail page with stats after evaluations" do
    Onni.ready!(:demo)
    Onni.visible?(:demo)
    Onni.park!(:demo)
    Onni.visible?(:demo)

    get admin_feature_path("demo")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("demo")
    expect(response.body).to include("Evaluations")
    expect(response.body).to include("Sample rate")
    expect(response.body).to include(Onni.configuration.stats_sample_rate.to_s)
    expect(response.body).to include("main-content-container")
    expect(response.body).to include("formtastic")
  end

  it "forbids page actions when admin_authorized fails" do
    Onni.configuration.admin_authorized = -> { false }

    get admin_features_path
    expect(response).to have_http_status(:forbidden)

    get admin_features_stats_path
    expect(response).to have_http_status(:forbidden)

    post admin_features_ready_path(key: "demo")
    expect(response).to have_http_status(:forbidden)
    post admin_features_park_path(key: "demo")
    expect(response).to have_http_status(:forbidden)
    expect(Onni.pending?(:demo)).to be(true)
  ensure
    Onni.configuration.admin_authorized = -> { true }
  end

  it "parks a flag through the page action" do
    Onni.ready!(:demo)

    post admin_features_park_path(key: "demo")

    expect(response).to redirect_to(admin_features_path)
    expect(Onni.visible?(:demo)).to be(false)
    expect(Onni.parked?(:demo)).to be(true)
  end

  it "returns not found for unknown power commands" do
    post admin_features_ready_path(key: "missing")
    expect(response).to have_http_status(:not_found)
    post admin_features_park_path(key: "missing")
    expect(response).to have_http_status(:not_found)
  end

  it "removes the transitional power routes" do
    %w[show skip enable disable].each do |action|
      expect {
        Rails.application.routes.recognize_path("/admin/features/#{action}", method: :post)
      }.to raise_error(ActionController::RoutingError)
    end
  end

  it "configures filters independently of power and preserves them across park and ready" do
    Onni.register_group(:staff) { |_actor, _| true }
    post admin_features_update_feature_path(key: "search_v2"), params: {filter: "level", value: "40"}
    expect(response).to redirect_to(admin_feature_path("search_v2"))
    expect(Onni.level(:search_v2)).to eq(40)

    post admin_features_update_feature_path(key: "demo"), params: {variants: {control: "30", treatment: "70"}}
    expect(response).to redirect_to(admin_feature_path("demo"))
    expect(Onni.variants(:demo)).to eq("control" => 30, "treatment" => 70)

    post admin_features_update_feature_path(key: "audience"), params: {filter: "groups", value: "staff"}
    expect(Onni.pending?(:audience)).to be(true)
    Onni.ready!(:audience)
    expect(Onni.visible?(:audience, Object.new, record_stats: false)).to be(true)
    post admin_features_park_path(key: "audience")
    expect(Onni[:audience].filters["groups"]).to eq(["staff"])
    post admin_features_ready_path(key: "audience")
    expect(Onni.visible?(:audience, Object.new, record_stats: false)).to be(true)
    post admin_features_update_feature_path(key: "audience"), params: {filter: "groups", value: ""}
    expect(Onni.visible?(:audience, Object.new, record_stats: false)).to be(false)
  end

  it "rejects malformed settings without applying changes" do
    post admin_features_update_feature_path(key: "search_v2"), params: {filter: "level", value: "invalid"}
    expect(response).to have_http_status(422)
    expect(Onni.ready?(:search_v2)).to be(false)
    post admin_features_update_feature_path(key: "demo"), params: {variants: {control: "invalid"}}
    expect(response).to have_http_status(422)
    expect(Onni.variants(:demo)).to eq("control" => 50, "treatment" => 50)
  end

  it "shows a park command for a powered zero-percent rollout" do
    Onni.level!(:search_v2, 0)
    get admin_features_path
    document = Nokogiri::HTML(response.body)
    row = document.at_css('a[href$="/admin/features/search_v2"]').ancestors("tr").first
    expect(row.at_css("button[type=submit]").text).to eq("Park")
    expect(row.text).to include("Ready")

    get admin_feature_path("search_v2")
    document = Nokogiri::HTML(response.body)
    status = document.css("tr").find { |entry| entry.at_css("th")&.text == "Status" }
    expect(status.at_css("td").text.strip).to eq("Ready")
  end

  it "renders editable filters for ordinary flags and experiments" do
    get admin_feature_path("search_v2")
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('input[name="value"][type="number"]')).to be_present
    expect(document.at_css('textarea[name="value"]')).to be_present
    expect(document.at_css('input[name="variants[control]"]')).to be_nil
  end

  it "preserves custom variant names when editing an experiment" do
    Onni.variants!(:demo, blue: 20, green: 80)
    get admin_feature_path("demo")
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('input[name="variants[blue]"]')["value"]).to eq("20")
    expect(document.at_css('input[name="variants[green]"]')["value"]).to eq("80")
  end

  it "uses the query-key detail route for reserved flag names" do
    definitions = Onni::Registry.config.merge(%w[ready park pending visible show skip].to_h { |name| [name, {"everyone" => true}] })
    allow(Onni::Registry).to receive(:config).and_return(definitions)
    get admin_features_path
    document = Nokogiri::HTML(response.body)
    %w[ready park pending visible show skip].each do |name|
      link = document.css("a").find { |element| element.text == name }
      expect(link["href"]).to eq(admin_features_feature_path(key: name))
      get link["href"]
      expect(response).to have_http_status(:ok)
      post admin_features_ready_path(key: name)
      expect(Onni.visible?(name, record_stats: false)).to be(true)
    end
  end

  it "shows one ready or park command per flag and relative expiry" do
    Onni.ready!(:demo)

    get admin_features_path

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    demo_row = document.at_css("a[href$=\"/admin/features/demo\"]")&.ancestors("tr")&.first
    search_row = document.at_css("a[href$=\"/admin/features/search_v2\"]")&.ancestors("tr")&.first
    expect(demo_row.at_css("button[type=submit]").text).to eq("Park")
    expect(demo_row.at_css("button[type=submit]").text).not_to eq("Ready")
    expect(search_row.at_css("button[type=submit]").text).to eq("Ready")
    expires = demo_row.at_css("[data-onni-expires]")
    expect(expires["title"]).to eq("2099-01-01")
    expect(expires.text).to match(/\d+ years?/)
  end
end
