# frozen_string_literal: true

require "spec_helper"
require "active_support/notifications"

RSpec.describe "Onni stats instrumentation" do
  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
  end

  it "instruments kept stats writes" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("stats.record.onni") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    Onni::Stats.record("demo", shown: true)

    expect(events.size).to eq(1)
    expect(events.first.payload).to include(name: "demo", shown: true, weight: 1)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "does not instrument skipped samples" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("stats.record.onni") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
    Onni.configuration.stats_ignore = %w[demo]

    Onni::Stats.record("demo", shown: true)

    expect(events).to be_empty
  ensure
    Onni.configuration.stats_ignore = []
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "instruments purge results" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("stats.purge.onni") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    result = Onni::Stats.purge!(older_than: Time.now.utc)

    expect(events.size).to eq(1)
    expect(events.first.payload[:processed_count]).to eq(result[:processed_count])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
