# frozen_string_literal: true

require "spec_helper"
require "active_support/notifications"

RSpec.describe Onni::Instrumenter do
  around do |example|
    previous = Onni.configuration.instrumenter
    example.run
  ensure
    Onni.configuration.instrumenter = previous
  end

  it "publishes ActiveSupport::Notifications under the .onni suffix" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe(/\.onni$/) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    result = described_class.instrument("stats.record", name: "demo") { :ok }

    expect(result).to eq(:ok)
    expect(events.map(&:name)).to include("stats.record.onni")
    expect(events.first.payload[:name]).to eq("demo")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "yields the payload when no backend is configured" do
    Onni.configuration.instrumenter = nil

    captured = nil
    result = described_class.instrument("stats.record", name: "demo") { |payload|
      captured = payload
      :ok
    }

    expect(result).to eq(:ok)
    expect(captured).to eq(name: "demo")
  end
end
