# frozen_string_literal: true

require "spec_helper"
require "active_support/notifications"

RSpec.describe "Onni feature_operation instrumentation" do
  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    allow(Onni::Registry).to receive(:require_definition!)
    allow(Onni::Registry).to receive_messages(known?: true, definition: {"description" => "Demo", "expires_at" => "2099-01-01"})
  end

  def capture_operations
    events = []
    subscription = ActiveSupport::Notifications.subscribe("feature_operation.onni") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
    yield
    events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  it "instruments enable_group and set_variants mutations" do
    Onni.register_group(:staff) { |_actor, _| true }

    events = capture_operations do
      Onni.enable_group(:demo, :staff)
      Onni.set_variants(:demo, {control: 40, treatment: 60})
    end

    expect(events.map { |event| event.payload[:operation] }).to eq([:enable_group, :set_variants])
    expect(events.first.payload).to include(feature_name: "demo", group_name: "staff", result: true)
    expect(events.last.payload).to include(feature_name: "demo", result: true)
  end

  it "instruments disable_group and percentage mutations" do
    events = capture_operations do
      Onni.enable_percentage_of_actors(:demo, 250)
      Onni.disable_group(:demo, :staff)
    end

    expect(events.map { |event| event.payload[:operation] }).to eq([:enable_percentage_of_actors, :disable_group])
    expect(events.first.payload[:percentage]).to eq(100)
  end
end
