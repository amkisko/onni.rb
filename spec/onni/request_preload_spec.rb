# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Onni request preload" do
  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    Onni.reset_request!
    allow(Onni::Registry).to receive(:require_definition!)
    allow(Onni::Registry).to receive_messages(
      known?: true,
      definition: {"description" => "Demo", "expires_at" => "2099-01-01"},
      config: {"demo" => {}, "search_v2" => {}}
    )
    Onni.enable(:demo)
    Onni.enable(:search_v2)
  end

  after { Onni.reset_request! }

  it "loads many gates in one adapter call and serves enabled? from the request store" do
    expect(Onni.adapter).to receive(:gates_for_many).once.and_call_original
    expect(Onni.adapter).not_to receive(:gates_for)

    expect(Onni.preload!).to eq(2)
    expect(Onni.enabled?(:demo)).to be(true)
    expect(Onni.enabled?(:search_v2)).to be(true)
  end

  it "drops preloaded gates on reset_request!" do
    Onni.preload!(:demo)
    Onni.reset_request!
    expect(Onni.adapter).to receive(:gates_for).once.and_call_original
    expect(Onni.enabled?(:demo)).to be(true)
  end
end
