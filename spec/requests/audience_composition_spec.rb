# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Persisted audience composition", type: :request do
  let(:actor) { Struct.new(:id).new(7) }
  let(:other) { Struct.new(:id).new(8) }

  before do
    Onni.register_group(:beta_testers) { |candidate, _| candidate.id == 7 }
    Onni.register_group(:staff) { |candidate, _| candidate.id == 8 }
  end

  it "rebuilds composed overrides from committed rows and YAML after cache loss" do
    Onni.configuration.cache = ActiveSupport::Cache::MemoryStore.new
    Onni.filters!(:demo, groups: %w[beta_testers staff], excluded_groups: ["staff"], level: 100)
    Onni.variants!(:demo, treatment: 100)
    Onni.ready!(:demo)
    Onni.preload!(:demo)
    expect(Onni.variant(:demo, actor, record_stats: false)).to eq(:treatment)
    expect(Onni.variant(:demo, other, record_stats: false)).to be_nil
    Onni.park!(:demo)
    Onni.reset_adapter!
    Onni.configuration.cache.clear
    Onni.reset_request!
    Onni::Registry.reload!
    expect(Onni.parked?(:demo)).to be(true)
    expect(Onni[:demo].filters).to include("groups" => %w[beta_testers staff], "level" => 100)
    Onni.ready!(:demo)
    expect(Onni.variant(:demo, actor, record_stats: false)).to eq(:treatment)
    expect(Onni.variant(:demo, other, record_stats: false)).to be_nil
    Onni.filters!(:demo, groups: nil, excluded_groups: nil, level: nil)
    Onni.configuration.cache.clear
    Onni.reset_request!
    expect(Onni.visible?(:demo, record_stats: false)).to be(true)
  end

  it "counts one feature outcome per assignment including audience rejections" do
    Onni.filters!(:demo, groups: ["beta_testers"], level: 100)
    Onni.ready!(:demo)
    expect(Onni.variant(:demo, actor)).to be_a(Symbol)
    expect(Onni.variant(:demo, other)).to be_nil
    rows = Onni::Stats.for(:demo)
    expect(rows.sum { |row| row.fetch("shown_count") }).to eq(1)
    expect(rows.sum { |row| row.fetch("skip_count") }).to eq(1)
  end

  it "fails closed for malformed persisted filters instead of widening defaults" do
    ["{bad", "[]", '{"level":"100"}', '{"excluded_actors":[null]}'].each do |value|
      Onni.adapter.replace_gates(:demo, [{key: "powered", value: "true"},
        {key: "audience_filters", value: value}])
      expect(Onni.visible?(:demo, actor, record_stats: false)).to be(false)
      expect(Onni.variant(:demo, actor, record_stats: false)).to be_nil
    end
  end

  it "supports adding and dropping includes after bulk filter updates" do
    Onni.filters!(:demo, groups: ["staff"], level: 100)
    Onni.visible_group!(:demo, :beta_testers)
    expect(Onni.visible?(:demo, actor, record_stats: false)).to be(true)
    Onni.drop_group!(:demo, :beta_testers)
    expect(Onni.visible?(:demo, actor, record_stats: false)).to be(false)
    Onni.level!(:demo, 0)
    expect(Onni.level(:demo)).to eq(0)
    Onni.filters!(:demo, groups: nil, level: nil)
    expect(Onni.visible?(:demo, record_stats: false)).to be(true)
  end
end
