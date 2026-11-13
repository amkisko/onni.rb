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
      definition: {"everyone" => true, "description" => "Demo", "expires_at" => "2099-01-01"},
      config: {"demo" => {"everyone" => true}, "search_v2" => {"everyone" => true}}
    )
    Onni.ready!(:demo)
    Onni.ready!(:search_v2)
  end

  after { Onni.reset_request! }

  it "loads many gates in one adapter call and serves visible? from the request store" do
    expect(Onni.adapter).to receive(:gates_for_many).once.and_call_original
    expect(Onni.adapter).not_to receive(:gates_for)
    expect(Onni.adapter).not_to receive(:gates_snapshot_for)

    expect(Onni.preload!).to eq(2)
    expect(Onni.visible?(:demo)).to be(true)
    expect(Onni.visible?(:search_v2)).to be(true)
  end

  it "drops preloaded gates on reset_request!" do
    Onni.preload!(:demo)
    Onni.reset_request!
    expect(Onni.adapter).to receive(:gates_snapshot_for).once.and_call_original
    expect(Onni.visible?(:demo)).to be(true)
  end
end
