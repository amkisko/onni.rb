# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Delivery operator controls", type: :request do
  before do
    allow(Onni::Registry).to receive(:config).and_return(
      "new_checkout" => {"signals" => {"exception" => {"threshold" => 3}}, "expires_at" => "2000-01-01"}
    )
    allow(Onni::Delivery).to receive(:entries).and_return({})
    @delivery = Class.new(Onni::Delivery) do
      feature :new_checkout
      parked { :legacy }
      experiment(:new_flow, everyone: true) { :new }
    end
  end

  it "labels a Delivery feature on the Flags index and detail overview" do
    get admin_features_path
    document = Nokogiri::HTML(response.body)
    row = document.css("a").find { |link| link.text == "new_checkout" }&.ancestors("tr")&.first
    expect(row.text).to include("Delivery")

    get admin_features_feature_path(key: "new_checkout")
    expect(response).to have_http_status(:ok)
    overview = Nokogiri::HTML(response.body).css("tr").find { |entry| entry.at_css("th")&.text == "Assignment" }
    expect(overview.at_css("td").text.strip).to eq("Delivery")
  end

  it "edits experiment targeting, thresholds and resets without readying power" do
    path = admin_features_update_feature_path(key: "new_checkout")
    post path, params: {experiment: "new_flow", filter: "level", value: "25"}
    expect(response).to have_http_status(:redirect)
    expect(Onni.pending?(:new_checkout)).to be(true)
    Onni.ready!(:new_checkout)
    post path, params: {signal: "exception", threshold: "1"}
    expect(response).to have_http_status(:redirect)
    expect(Onni.observe!(:new_checkout, :exception)).to eq(1)
    expect(Onni.parked?(:new_checkout)).to be(true)
    post path, params: {reset_signal: "exception"}
    expect(response).to have_http_status(:redirect)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
    expect(Onni.parked?(:new_checkout)).to be(true)
    get admin_features_feature_path(key: "new_checkout")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Delivery experiments", "Signals", "Overdue")
    document = Nokogiri::HTML(response.body)
    identifiers = document.css("[id]").map { |element| element["id"] }
    expect(identifiers.uniq).to eq(identifiers)
    document.css("[aria-describedby]").each do |field|
      field["aria-describedby"].split.each { |identifier| expect(document.at_css("##{identifier}")).to be_present }
    end
  end

  it "protects all operator mutations with the host policy" do
    Onni.configuration.admin_authorized = -> { false }
    post admin_features_update_feature_path(key: "new_checkout"), params: {signal: "exception", threshold: "1"}
    expect(response).to have_http_status(:forbidden)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
    expect(Onni.pending?(:new_checkout)).to be(true)
  end

  it "rejects unknown experiments, malformed thresholds and unauthorized fields" do
    path = admin_features_update_feature_path(key: "new_checkout")
    post path, params: {experiment: "missing", filter: "everyone", value: "true"}
    expect(response).to have_http_status(:unprocessable_content)
    post path, params: {signal: "exception", threshold: "1.5", powered: "true"}
    expect(response).to have_http_status(:unprocessable_content)
    expect(Onni.pending?(:new_checkout)).to be(true)
    expect(response.body).to include("1.5", "Signals", "Check the rollout settings.")
  end

  it "propagates transaction rollback without observing or running parked" do
    @delivery.define_method(:new_flow) { raise ActiveRecord::Rollback }
    @delivery.define_method(:parked) { raise "must not run" }
    Onni.ready!(:new_checkout)
    expect { @delivery.call }.to raise_error(ActiveRecord::Rollback)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
  end

  describe "concurrent durable updates", use_transactional_tests: false do
    it "publishes park only after commit and suppresses rolled-back observations" do
      events = []
      subscription = ActiveSupport::Notifications.subscribe("feature_operation.onni") { |event| events << event.payload.dup }
      Onni.configuration.cache = ActiveSupport::Cache::MemoryStore.new
      Onni.ready!(:new_checkout)
      events.clear
      Onni::Feature.transaction do
        Onni.observe!(:new_checkout, :exception, 3)
        Onni.preload!(:new_checkout)
        expect(Onni.parked?(:new_checkout)).to be(true)
        expect(events).to eq([])
        raise ActiveRecord::Rollback
      end
      expect(events).to eq([])
      expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
      expect(Onni.ready?(:new_checkout)).to be(true)
      Onni::Feature.transaction do
        Onni.observe!(:new_checkout, :exception, 3)
        expect(events).to eq([])
      end
      expect(events.map { |event| event[:operation] }).to eq([:observe, :park])
      expect(Onni.parked?(:new_checkout)).to be(true)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    it "retains every increment across distinct adapters and pooled connections" do
      Onni.ready!(:new_checkout)
      writers = Array.new(4) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            20.times { Onni.observe!(:new_checkout, :exception) }
          end
        end
      end
      writers.each(&:value)
      Onni.adapter = Onni::Adapters::ActiveRecord.new
      expect(Onni.signal_level(:new_checkout, :exception)).to eq(80)
      expect(Onni.parked?(:new_checkout)).to be(true)
    end
  end
end
