# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveAdmin stats overview", type: :request do
  it "shows hit storage overview and cleanup guidance on the features index" do
    Onni::StatBucket.create!(
      feature_key: "demo",
      period: "hour",
      period_start: 5.days.ago.utc.beginning_of_hour,
      enabled_hits: 1,
      disabled_hits: 0
    )

    get admin_features_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hit storage")
    expect(response.body).to include("Buckets")
    expect(response.body).to include("cleanup")
  end

  it "prompts to schedule cleanup when there are no hit buckets" do
    get admin_features_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No hit buckets yet")
  end

  it "warns when oldest hit history is past retention" do
    previous = Onni.configuration.stats_retention
    Onni.configuration.stats_retention = 2.days
    Onni::StatBucket.create!(
      feature_key: "demo",
      period: "hour",
      period_start: 10.days.ago.utc.beginning_of_hour,
      enabled_hits: 1,
      disabled_hits: 0
    )

    get admin_features_path

    expect(response.body).to include("past retention")
  ensure
    Onni.configuration.stats_retention = previous
  end

  it "warns when hit storage is large" do
    allow(Onni.adapter).to receive(:stats_overview).and_return(
      bucket_count: Onni::Stats::Overview::ROW_WARNING,
      oldest_period_start: 1.day.ago
    )

    get admin_features_path

    expect(response.body).to include("Hit storage is large")
  end
end
