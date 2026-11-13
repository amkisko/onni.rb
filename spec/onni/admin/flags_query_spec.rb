# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::Admin::FlagsQuery do
  it "scopes ready, pending, and parked flags and reports counts" do
    Onni.ready!(:demo)
    Onni.park!(:audience)

    query = described_class.new(scope: "ready")
    expect(query.flags.map(&:name)).to include("demo")
    expect(query.flags.map(&:name)).not_to include("search_v2")
    expect(query.scope_counts).to include("all" => be > 0, "ready" => 1, "parked" => 1, "pending" => be >= 1)

    pending = described_class.new(scope: "pending", q: "search")
    expect(pending.flags.map(&:name)).to eq(["search_v2"])
    expect(described_class.new(scope: "parked").flags.map(&:name)).to eq(["audience"])
  end

  it "reads only filter keys from ActionController::Parameters" do
    params = ActionController::Parameters.new(q: "demo", scope: "all", other: "x")
    query = described_class.new(params)
    expect(query.search).to eq("demo")
    expect(query.scope).to eq("all")
  end

  it "keeps powered audience misses ready without recording evaluations" do
    Onni.level!(:search_v2, 0)
    expect(Onni.visible?(:search_v2, record_stats: false)).to be(false)

    ready = described_class.new(scope: "ready")
    parked = described_class.new(scope: "parked")
    expect {
      expect(ready.flags.map(&:name)).to eq(["search_v2"])
      expect(parked.flags.map(&:name)).not_to include("search_v2")
      expect(ready.scope_counts).to include("ready" => 1, "parked" => 0)
    }.not_to change(Onni::StatBucket, :count)
  end
end
