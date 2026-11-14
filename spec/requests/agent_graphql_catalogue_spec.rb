# frozen_string_literal: true

require "rails_helper"
require_relative "../support/agent_access"

RSpec.describe "Onni GraphQL catalogue and settings", type: :request do
  include_context "with device-authorized Onni"

  it "pages the catalogue through one bounded gate read without recording evaluations" do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      queries << event.payload[:name] if event.payload[:name] == "Onni::Gate Load"
    end
    data = graphql("{ onni { features(first: 2) { items { name power } next_cursor total_count } } }")
    expect(data["errors"]).to be_nil
    page = data.dig("data", "onni", "features")
    expect(page.fetch("items").map { |item| item.fetch("name") }).to eq(%w[audience demo])
    expect(queries.size).to eq(1)
    data = graphql("query($after: String) { onni { features(first: 2, after: $after) { items { name } next_cursor } } }",
      variables: {after: page.fetch("next_cursor")})
    expect(data.dig("data", "onni", "features", "items").map { |item| item["name"] }).to eq(%w[search_v2 selected])
    expect(data.dig("data", "onni", "features", "next_cursor")).to be_nil
    expect(Onni::StatBucket.count).to eq(0)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "bounds list and statistics queries and handles unknown features" do
    [0, 101].each do |first|
      data = graphql("query($first: Int!) { onni { features(first: $first) { items { name } } } }", variables: {first: first})
      expect(data["errors"]).to be_present
    end
    data = graphql('{ onni { feature(name: "missing") { name } } }')
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "onni", "feature")).to be_nil
    data = graphql('{ onni { feature(name: "demo") { statistics(hours: 721) { shown_count } } } }')
    expect(data["errors"]).to be_present
    expect(Onni::StatBucket.count).to eq(0)
  end

  it "updates audience, variant weights and stats through validated domain mutations" do
    data = graphql('mutation { onni_set_filters(name: "demo", filters: {everyone: false, level: 25}) { filters { everyone level } } }')
    expect(data["errors"]).to be_nil
    expect(Onni[:demo].filters).to include("everyone" => false, "level" => 25)
    data = graphql('mutation { onni_set_variants(name: "demo", variants: [{name: "control", weight: "10"}, {name: "treatment", weight: "90"}]) { variants { name weight } } }')
    expect(data["errors"]).to be_nil
    expect(Onni.variants(:demo)).to eq("control" => 10, "treatment" => 90)
    data = graphql('mutation { onni_set_stats(name: "demo", stats: {enabled: false, sample_rate: 0.25}) { stats { enabled sample_rate } } }')
    expect(data["errors"]).to be_nil
    expect(Onni[:demo].stats_settings).to eq("enabled" => false, "sample_rate" => 0.25)
    expect(Onni.pending?(:demo)).to be(true)
  end

  it "reads stored evaluation counts without adding another evaluation" do
    Onni.adapter.record_stat(:demo, shown: true, weight: 3)
    Onni.adapter.record_stat(:demo, shown: false, weight: 2)
    data = graphql('{ onni { feature(name: "demo") { statistics(hours: 24) { period_start shown_count skip_count } } } }')
    expect(data["errors"]).to be_nil
    buckets = data.dig("data", "onni", "feature", "statistics")
    expect(buckets.size).to eq(1)
    expect(buckets.first).to include("shown_count" => "3", "skip_count" => "2")
    expect(Time.iso8601(buckets.first.fetch("period_start"))).to eq(Time.current.utc.beginning_of_hour)
    expect(Onni::Stats.for(:demo).first).to include("shown_count" => 3, "skip_count" => 2)
  end

  it "rejects unknown inputs, out-of-range filters and duplicate variant names without writing gates" do
    documents = [
      'mutation { onni_set_filters(name: "demo", filters: {level: 101}) { name } }',
      'mutation { onni_set_filters(name: "demo", filters: {powered: true}) { name } }',
      'mutation { onni_set_variants(name: "demo", variants: [{name: "control", weight: "10"}, {name: "control", weight: "90"}]) { name } }',
      'mutation { onni_ready(name: "missing") { power } }'
    ]
    documents.each do |document|
      expect(graphql(document)["errors"]).to be_present
      expect(Onni.adapter.gates_for(:demo)).to eq([])
      expect(Onni.exist?(:missing)).to be(false)
    end
  end

  it "tunes a registered Delivery experiment without changing pending power" do
    allow(Onni::Delivery).to receive(:entries).and_return({})
    Class.new(Onni::Delivery) do
      feature :search_v2
      parked { :legacy }
      experiment(:new_flow, everyone: true) { :new }
    end
    data = graphql('mutation { onni_set_experiment_filters(name: "search_v2", experiment: "new_flow", filters: {level: 50}) { power experiments { name filters { level } } } }')
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "onni_set_experiment_filters", "experiments")).to eq([
      {"name" => "new_flow", "filters" => {"level" => 50}}
    ])
    expect(Onni.pending?(:search_v2)).to be(true)
  end

  it "keeps existing host fields and makes schema installation idempotent" do
    namespace = ActiveAdmin.application.namespaces[:admin]
    namespace.graphql_configure_schema = lambda do |schema|
      schema.query.field :host_status, String, null: false, camelize: false
      schema.query.define_method(:host_status) { "ready" }
      Onni::Admin::GraphQL.install!(schema)
      Onni::Admin::GraphQL.install!(schema)
    end
    ActiveAdmin::GraphQL.clear_schema_cache!
    data = graphql('{ host_status onni { feature(name: "demo") { name } } }')
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "host_status")).to eq("ready")
    expect(data.dig("data", "onni", "feature", "name")).to eq("demo")
  end
end

RSpec.describe "Onni GraphQL schema configuration", type: :request do
  include_context "with device-authorized Onni"

  it "works with generic resource/policy queries disabled" do
    namespace = ActiveAdmin.application.namespaces[:admin]
    previous = namespace.graphql_policies_enabled
    namespace.graphql_policies_enabled = false
    ActiveAdmin::GraphQL.clear_schema_cache!
    data = graphql("{ onni { features(first: 1) { items { name } } } }")
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "onni", "features", "items").length).to eq(1)
  ensure
    namespace.graphql_policies_enabled = previous
    ActiveAdmin::GraphQL.clear_schema_cache!
  end

  it "does not partially install commands when an inherited host field collides" do
    namespace = ActiveAdmin.application.namespaces[:admin]
    namespace.graphql_configure_schema = lambda do |schema|
      mutation = Class.new(GraphQL::Schema::Object) do
        graphql_name "Mutation"
        field :onni_set_stats, String, null: false, camelize: false
        define_method(:onni_set_stats) { "host" }
      end
      schema.mutation(Class.new(mutation) { graphql_name "Mutation" })
      begin
        Onni::Admin::GraphQL.install!(schema)
      rescue ArgumentError
        nil
      end
    end
    ActiveAdmin::GraphQL.clear_schema_cache!
    data = graphql("{ __schema { mutationType { fields { name } } } }")
    expect(data["errors"]).to be_nil
    expect(data.dig("data", "__schema", "mutationType", "fields")).to eq([{"name" => "onni_set_stats"}])
  end

  it "honors individual host command policies and hides blocked fields from introspection" do
    authorization = Class.new(AgentAccess::Authorization) do
      def authorized?(action, subject = nil)
        action != :park && super
      end
    end
    ActiveAdmin.application.namespaces[:admin].authorization_adapter = authorization
    data = graphql("{ __schema { mutationType { fields { name } } } }")
    names = data.dig("data", "__schema", "mutationType", "fields").map { |field| field["name"] }
    expect(names).to include("onni_ready")
    expect(names).not_to include("onni_park")
    graphql('mutation { onni_ready(name: "demo") { power } }')
    expect(Onni.ready?(:demo)).to be(true)
    expect(graphql('mutation { onni_park(name: "demo") { power } }')["errors"]).to be_present
    expect(Onni.ready?(:demo)).to be(true)
  end
end
