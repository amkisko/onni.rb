# frozen_string_literal: true

require "spec_helper"
require "active_support/notifications"

RSpec.describe "Onni feature_operation instrumentation" do
  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    allow(Onni::Registry).to receive(:require_definition!)
    allow(Onni::Registry).to receive(:known?).and_return(true)
    allow(Onni::Registry).to receive(:definition) do |name|
      {"type" => {demo: "group", experiment: "experiment", rollout: "percentage"}.fetch(name)}
    end
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

  it "instruments visible_group and variants mutations" do
    Onni.register_group(:staff) { |_actor, _| true }

    events = capture_operations do
      Onni.visible_group!(:demo, :staff)
      Onni.variants!(:experiment, {control: 40, treatment: 60})
    end

    expect(events.map { |event| event.payload[:operation] }).to eq([:visible_group, :variants])
    expect(events.first.payload).to include(feature_name: "demo", group_name: "staff", result: true)
    expect(events.last.payload).to include(feature_name: "experiment", result: true)
  end

  it "instruments drop_group and level mutations" do
    events = capture_operations do
      Onni.level!(:rollout, 250)
      Onni.drop_group!(:demo, :staff)
    end

    expect(events.map { |event| event.payload[:operation] }).to eq([:level, :drop_group])
    expect(events.first.payload[:level]).to eq(100)
  end
end
