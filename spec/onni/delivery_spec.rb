# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Delivery execution" do
  let(:definition) { {"everyone" => false, "signals" => {"exception" => {"threshold" => 2}}} }
  let(:delivery) do
    Class.new(Onni::Delivery) do
      feature :new_checkout
      parked { |order:| "legacy:#{order}" }
      experiment(:new_flow, everyone: true) { |order:| "new:#{order}" }
    end
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    allow(Onni.configuration).to receive(:cache).and_return(nil)
    allow(Onni::Registry).to receive(:config).and_return("new_checkout" => definition)
    allow(Onni::Delivery).to receive(:entries).and_return({})
    Onni.reset_request!
  end

  it "always runs parked for pending/parked power and selects without feature audience or shown counts" do
    expect(delivery.call(order: 7)).to eq("legacy:7")
    Onni.ready!(:new_checkout)
    expect(Onni.selected(:new_checkout)).to eq(:new_flow)
    expect(delivery.call(order: 7)).to eq("new:7")
    Onni.park!(:new_checkout)
    expect(delivery.call(order: 7)).to eq("legacy:7")
    expect(Onni::Stats.for(:new_checkout)).to eq([])
  end

  it "uses the first matching arm and merges runtime overrides without boot writes" do
    delivery
    delivery.experiment(:other, everyone: true) { |order:| "other:#{order}" }
    expect(Onni.exist?(:new_checkout)).to be(false)
    Onni.ready!(:new_checkout)
    Onni.experiment_filters!(:new_checkout, :new_flow, everyone: false)
    expect(delivery.call(order: 8)).to eq("other:8")
    Onni.clear!(:new_checkout)
    Onni.ready!(:new_checkout)
    expect(delivery.call(order: 8)).to eq("new:8")
    expect { Onni.experiment_filters!(:new_checkout, :missing, everyone: true) }.to raise_error(ArgumentError)
  end

  it "merges catalogue experiment targeting before runtime targeting" do
    definition["delivery_experiments"] = {"new_flow" => {"everyone" => false}}
    Onni.ready!(:new_checkout)
    expect(delivery.call(order: 1)).to eq("legacy:1")
    Onni.experiment_filters!(:new_checkout, :new_flow, everyone: true)
    expect(delivery.call(order: 1)).to eq("new:1")
    Onni.clear!(:new_checkout)
    Onni.ready!(:new_checkout)
    expect(delivery.call(order: 1)).to eq("legacy:1")
  end

  it "does not evaluate later audiences after the first match" do
    delivery.experiment(:later, groups: ["broken"]) { |order:| order }
    Onni.register_group(:broken) { raise "must not evaluate later audiences" }
    Onni.ready!(:new_checkout)
    expect(delivery.call(Struct.new(:id).new(7), order: 1)).to eq("new:1")
  end

  it "falls back once, counts exceptions, parks at threshold, and propagates parked failures" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("delivery_error.onni") { |event| events << event.payload.dup }
    delivery.define_method(:new_flow) { |**| raise IOError, "unavailable" }
    Onni.ready!(:new_checkout)
    expect(delivery.call(order: 1)).to eq("legacy:1")
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(1)
    expect(delivery.call(order: 2)).to eq("legacy:2")
    expect(Onni.parked?(:new_checkout)).to be(true)
    delivery.define_method(:parked) { |**| raise "legacy failed" }
    expect { delivery.call(order: 3) }.to raise_error(RuntimeError, "legacy failed")
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(2)
    expect(events).to eq(Array.new(2) { {feature_name: "new_checkout", experiment: :new_flow, error_class: "IOError"} })
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "falls back on programming errors without counting them unless opted in" do
    delivery.define_method(:new_flow) { |**| raise NoMethodError, "mistake" }
    Onni.ready!(:new_checkout)
    expect(delivery.call(order: 1)).to eq("legacy:1")
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
    delivery.rescue_policy(count_programming_errors: true)
    delivery.call(order: 2)
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(1)
  end

  it "rejects an undeclared rescue signal before running business code" do
    expect { delivery.rescue_policy(signal: :missing) }.to raise_error(ArgumentError)
    Onni.signals!(:new_checkout, hold: {threshold: 1})
    delivery.rescue_policy(signal: :hold)
    delivery.define_method(:new_flow) { |**| raise IOError }
    Onni.ready!(:new_checkout)
    expect(delivery.call(order: 1)).to eq("legacy:1")
    expect(Onni.signal_level(:new_checkout, :hold)).to eq(1)
    expect(Onni.parked?(:new_checkout)).to be(true)
  end

  it "does not rescue exit-like failures or targeting errors" do
    delivery.define_method(:new_flow) { |**| raise SystemExit, 3 }
    Onni.ready!(:new_checkout)
    expect { delivery.call(order: 1) }.to raise_error(SystemExit)
    Onni.register_group(:broken) { raise "targeting failed" }
    Onni.experiment_filters!(:new_checkout, :new_flow, groups: ["broken"])
    expect { delivery.call(Struct.new(:id).new(7), order: 1) }.to raise_error(RuntimeError, "targeting failed")
    expect(Onni.signal_level(:new_checkout, :exception)).to eq(0)
  end

  it "rejects unknown catalogue arms for inline delivery before running a path" do
    definition["delivery_experiments"] = {"missing" => {"everyone" => true}}
    Onni.ready!(:new_checkout)
    expect { Onni.deliver(:new_checkout, parked: -> { :legacy }) { :new } }.to raise_error(ArgumentError)
  end

  it "shares execution with inline delivery and keeps selected meaningful" do
    Onni.ready!(:new_checkout)
    expect(Onni.deliver(:new_checkout, parked: -> { :legacy }) { :new }).to eq(:new)
    expect(Onni.selected(:new_checkout)).to eq(:on)
    Onni.experiment_filters!(:new_checkout, :on, everyone: false)
    expect(Onni.deliver(:new_checkout, parked: -> { :legacy }) { raise "not run" }).to eq(:legacy)
    expect { delivery }.to raise_error(ArgumentError)
  end

  it "rejects reserved names and missing bodies before running a path" do
    %i[parked on call feature class object selected deliver send initialize if].each do |name|
      expect { delivery.experiment(name, everyone: true) }.to raise_error(ArgumentError)
    end
    delivery.experiment(:missing_body, everyone: true)
    expect { delivery.call(order: 1) }.to raise_error(ArgumentError, /missing_body/)
  end

  it "requires an opener and forwards positional arguments, keywords and blocks" do
    klass = Class.new(Onni::Delivery) do
      feature :new_checkout
      experiment :new_flow
      def parked(value, scale:, &block)
        block.call(value * scale)
      end

      def new_flow(value, scale:, &block)
        block.call(value + scale)
      end
    end
    Onni.ready!(:new_checkout)
    expect(klass.call(nil, 3, scale: 4) { |value| value + 1 }).to eq(13)
    Onni.experiment_filters!(:new_checkout, :new_flow, everyone: true)
    expect(klass.call(nil, 3, scale: 4) { |value| value + 1 }).to eq(8)
  end
end
