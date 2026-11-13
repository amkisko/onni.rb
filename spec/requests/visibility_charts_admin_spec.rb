# frozen_string_literal: true

require "rails_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Onni ActiveAdmin visibility charts", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  it "shows an accessible chart and matching totals without recording evaluations" do
    Onni.adapter.record_stat("demo", shown: true, weight: 3)
    Onni.adapter.record_stat("demo", shown: false, weight: 1)

    expect { get admin_features_feature_path(key: "demo") }.not_to change { Onni::StatBucket.sum(:shown_count) }

    document = Nokogiri::HTML(response.body)
    chart = document.at_css('svg[role="img"]')
    expect(response).to have_http_status(:ok)
    expect(chart).to be_present
    expect(chart["aria-labelledby"].split.all? { |id| document.at_css("##{id}").present? }).to be(true)
    expect(document.at_css("[data-onni-shown-count]").text).to eq("3")
    expect(document.at_css("[data-onni-skip-count]").text).to eq("1")
    expect(document.at_css("[data-onni-shown-share]").text).to eq("75.0%")
    expect(document.css("details table tbody tr").size).to eq(24)
    expect(document.at_css('form[method="get"] select[name="range"]')).to be_present
  end

  it "changes the selected range and includes older evaluations" do
    travel_to(5.days.ago) { Onni.adapter.record_stat("demo", shown: true, weight: 9) }

    get admin_features_feature_path(key: "demo", range: "7d")

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.at_css("option[selected]")["value"]).to eq("7d")
    expect(document.at_css("[data-onni-shown-count]").text).to eq("9")
    expect(document.css("details table tbody tr").size).to eq(7)
  end

  it "shows an empty state without suggesting a measured zero percent" do
    get admin_features_feature_path(key: "demo")

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.at_css('[role="status"]').text).to include("No recorded evaluations")
    expect(document.at_css("[data-onni-shown-share]").text).to eq("No data")
    expect(document.at_css('svg[role="img"]')).to be_nil
  end

  ["365d", ["24h"], {"days" => "7"}].each do |range|
    it "rejects invalid range #{range.inspect}" do
      get admin_features_feature_path(key: "demo", range: range)

      expect(response).to have_http_status(:bad_request)
    end
  end

  it "applies dashboard authorization to charts" do
    Onni.configuration.admin_authorized = -> { false }

    get admin_features_feature_path(key: "demo", range: "30d")

    expect(response).to have_http_status(:forbidden)
  end

  it "lets the host replace the chart partial while retaining the statistics" do
    Onni.adapter.record_stat("demo", shown: true, weight: 5)
    original_paths = Admin::FeaturesController.view_paths
    Dir.mktmpdir("onni-host-views") do |root|
      directory = File.join(root, "admin/features")
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, "_chart.html.erb"), '<p id="host-chart">Custom chart: <%= chart.shown_count %></p>')
      Admin::FeaturesController.view_paths = original_paths.map do |resolver|
        (resolver.to_path == Rails.root.join("app/views").to_s) ? root : resolver
      end

      get admin_features_feature_path(key: "demo")

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:ok)
      expect(document.at_css("#host-chart")&.text).to eq("Custom chart: 5")
      expect(document.at_css("[data-onni-shown-count]").text).to eq("5")
    end
  ensure
    Admin::FeaturesController.view_paths = original_paths if original_paths
  end
end
