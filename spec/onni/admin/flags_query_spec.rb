# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::Admin::FlagsQuery do
  it "scopes enabled and disabled flags and reports counts" do
    Onni.enable(:demo)

    query = described_class.new(scope: "enabled")
    expect(query.flags.map(&:name)).to include("demo")
    expect(query.flags.map(&:name)).not_to include("search_v2")
    expect(query.scope_counts).to include("all" => be > 0, "enabled" => be >= 1, "disabled" => be >= 1)

    disabled = described_class.new(scope: "disabled", q: "search")
    expect(disabled.flags.map(&:name)).to eq(["search_v2"])
  end

  it "reads only filter keys from ActionController::Parameters" do
    params = ActionController::Parameters.new(q: "demo", scope: "all", other: "x")
    query = described_class.new(params)
    expect(query.search).to eq("demo")
    expect(query.scope).to eq("all")
  end
end
