# frozen_string_literal: true

require "spec_helper"
require_relative "../support/isolated_ruby"

RSpec.describe "Delivery catalogue ownership" do
  include IsolatedRuby

  it "owns its Ruby definition, survives reload, and rejects a different catalogue owner" do
    result = isolated_ruby(<<~RUBY, coverage_name: "delivery-ownership")
      require "onni"
      Onni.configuration.features_path = nil
      class CheckoutDelivery < Onni::Delivery
        feature :new_checkout, description: "Checkout", expires_at: "2099-01-01",
          signals: {exception: {threshold: 2}}, raise_on_expiration: true
        parked { :legacy }
        experiment(:new_flow, everyone: true) { :new }
      end
      Onni::Registry.reload!
      Onni.ready!(:new_checkout)
      rejected = begin
        Onni.define!(:new_checkout, description: "Other", expires_at: "2099-01-01")
        false
      rescue ArgumentError
        true
      end
      puts JSON.generate(value: CheckoutDelivery.call, rejected: rejected,
        description: Onni[:new_checkout].description)
    RUBY
    expect(result).to eq("value" => "new", "rejected" => true, "description" => "Checkout")
  end

  context "with runtime variant weights" do
    before do
      Onni.adapter = Onni::Adapters::Memory.new
      allow(Onni::Registry).to receive(:config).and_return("new_checkout" => {"type" => "experiment"})
      allow(Onni::Delivery).to receive(:entries).and_return({})
    end

    it "keeps one binding when declarations race" do
      # Yield after lock release to expose a check separated from its publication.
      allow(Onni::Sync).to receive(:synchronize).and_wrap_original do |method, &block|
        result = method.call(&block)
        Thread.pass
        result
      end
      results = Queue.new
      writers = Array.new(8) do
        Thread.new do
          Class.new(Onni::Delivery).feature(:new_checkout)
          results << :registered
        rescue ArgumentError
          results << :rejected
        end
      end
      writers.each(&:value)
      outcomes = Array.new(8) { results.pop }
      expect(outcomes.count(:registered)).to eq(1)
      expect(outcomes.count(:rejected)).to eq(7)
    end

    it "rejects a class arm that collides with existing runtime weights" do
      owner = Class.new(Onni::Delivery) { feature :new_checkout }
      Onni.variants!(:new_checkout, late_flow: 100)
      expect { owner.experiment(:late_flow, everyone: true) { :new } }.to raise_error(ArgumentError)
    end

    it "rejects an inline arm that collides with runtime weights" do
      Onni.variants!(:new_checkout, on: 100)
      expect { Onni.deliver(:new_checkout, parked: -> { :legacy }) { :new } }.to raise_error(ArgumentError)
    end
  end
end
