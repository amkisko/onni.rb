# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Typed visibility" do
  let(:actor) { Struct.new(:id).new(7) }
  let(:definitions) do
    {
      "new_checkout" => {"type" => "boolean"},
      "search_v2" => {"type" => "percentage", "level" => 100},
      "audience" => {"type" => "group", "groups" => ["beta_testers"]},
      "selected" => {"type" => "actors", "actors" => [Onni::Actor.id(actor)]},
      "experiment" => {"type" => "experiment", "variants" => {"control" => 100}}
    }
  end

  around do |example|
    previous = Onni.configuration.stats_enabled
    Onni.configuration.stats_enabled = true
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.reset_request!
    example.run
  ensure
    Onni.configuration.stats_enabled = previous
    Onni.reset_request!
    Onni::Group.clear!
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    allow(Onni::Registry).to receive(:config).and_return(definitions)
    Onni.register_group(:beta_testers) { |candidate, _| candidate.id == 7 }
  end

  it "requires power even when YAML defaults match" do
    definitions.each_key do |name|
      expect(Onni.visible?(name, actor)).to be(false)
      expect(Onni.ready?(name)).to be(false)
      expect(Onni::Stats.for(name)).to eq([])
      Onni.ready!(name)
      expect(Onni.visible?(name, actor)).to be(true)
      expect(Onni.ready?(name)).to be(true)
    end
  end

  it "parks before audience and conditions, without recording misses" do
    Onni.ready!(:audience)
    Onni.preload!(:audience)
    Onni.park!(:audience)
    expect(Onni::Group).not_to receive(:member?)
    expect(Onni::Actor).not_to receive(:percentage_value)
    expect(Onni::Conditions).not_to receive(:met?)
    3.times { expect(Onni.visible?(:audience, actor)).to be(false) }
    expect(Onni.variant(:audience, actor)).to be_nil
    expect(Onni::Stats.for(:audience)).to eq([])
  end

  it "records zero-percent soft misses but not hard-off misses" do
    Onni.level!(:search_v2, 0)
    expect(Onni.ready?(:search_v2)).to be(true)
    expect(Onni.visible?(:search_v2, actor)).to be(false)
    Onni.park!(:search_v2)
    expect(Onni.visible?(:search_v2, actor)).to be(false)
    expect(Onni::Stats.for(:search_v2).sum { |row| row.fetch("skip_count") }).to eq(1)
  end

  it "overrides defaults and restores them after clear then ready" do
    Onni.level!(:search_v2, 30)
    expect(Onni.level(:search_v2)).to eq(30)
    Onni.level!(:search_v2, 0)
    expect(Onni.level(:search_v2)).to eq(0)
    Onni.clear!(:search_v2)
    expect(Onni.ready?(:search_v2)).to be(false)
    Onni.ready!(:search_v2)
    expect(Onni.level(:search_v2)).to eq(100)
  end

  it "masks default group and actor audiences with empty overrides" do
    Onni.ready!(:audience)
    Onni.drop_group!(:audience, :beta_testers)
    expect(Onni.visible?(:audience, actor)).to be(false)
    Onni.visible_group!(:audience, :beta_testers)
    expect(Onni.visible?(:audience, actor)).to be(true)
    Onni.ready!(:selected)
    Onni.drop_actor!(:selected, actor)
    expect(Onni.visible?(:selected, actor)).to be(false)
    Onni.visible_actor!(:selected, actor)
    expect(Onni.visible?(:selected, actor)).to be(true)
    Onni.clear!(:audience)
    Onni.ready!(:audience)
    expect(Onni.visible?(:audience, actor)).to be(true)
    Onni.clear!(:selected)
    Onni.ready!(:selected)
    expect(Onni.visible?(:selected, actor)).to be(true)
  end

  it "uses runtime variant overrides and never assigns while parked" do
    Onni.variants!(:experiment, treatment: 100)
    expect(Onni.variant(:experiment, actor)).to be_nil
    Onni.ready!(:experiment)
    expect(Onni.variants(:experiment)).to eq("treatment" => 100)
    expect(Onni[:experiment].variants).to eq("treatment" => 100)
    expect(Onni.variant(:experiment, actor)).to eq(:treatment)
    Onni.park!(:experiment)
    expect(Onni.variant(:experiment, actor)).to be_nil
  end

  it "rejects mismatched mutations before touching runtime state" do
    expect { Onni.visible_group!(:new_checkout, :beta_testers) }.to raise_error(ArgumentError)
    expect { Onni.level!(:selected, 100) }.to raise_error(ArgumentError)
    expect { Onni.variants!(:audience, control: -1) }.to raise_error(ArgumentError)
    expect(Onni.adapter.feature_keys).to eq([])
  end

  it "fails closed for unknown names and rejects unknown mutations" do
    expect(Onni.visible?(:missing, actor)).to be(false)
    expect(Onni.ready?(:missing)).to be(false)
    expect { Onni.ready!(:missing) }.to raise_error(KeyError)
  end

  it "does not promote legacy actor gates into a global boolean audience" do
    Onni.adapter.replace_gates(:new_checkout, [{key: "actors", value: Onni::Actor.id(actor)}])
    expect(Onni.ready?(:new_checkout)).to be(false)
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
    expect(Onni::Stats.for(:new_checkout)).to eq([])
  end

  it "keeps a legacy audience powered when its last group is removed" do
    Onni.adapter.replace_gates(:audience, [{key: "groups", value: "beta_testers"}])
    expect(Onni.visible?(:audience, actor)).to be(true)
    Onni.drop_group!(:audience, :beta_testers)
    expect(Onni.ready?(:audience)).to be(true)
    expect(Onni.visible?(:audience, actor)).to be(false)
  end
end
