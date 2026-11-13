# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Audience filter composition" do
  let(:actor) { Struct.new(:id).new(7) }
  let(:other) { Struct.new(:id).new(8) }
  let(:definition) { {} }

  around do |example|
    previous_cache = Onni.configuration.cache
    example.run
  ensure
    Onni.reset_request!
    Onni.configuration.cache = previous_cache
    Onni::Group.clear!
  end

  before do
    Onni.configuration.cache = ActiveSupport::Cache::MemoryStore.new
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.reset_request!
    allow(Onni::Registry).to receive(:config).and_return("new_checkout" => definition)
    Onni.register_group(:beta_testers) { |candidate, _| candidate.id == 7 }
    Onni.register_group(:staff) { |candidate, _| candidate.id == 8 }
  end

  def visible(candidate = actor)
    Onni.visible?(:new_checkout, candidate, record_stats: false)
  end

  it "stays closed without a positive opener, including excludes alone" do
    Onni.ready!(:new_checkout)
    expect(visible).to be(false)
    Onni.filters!(:new_checkout, excluded_groups: ["staff"])
    expect(visible).to be(false)
  end

  it "intersects filters and allows alternatives only within each list" do
    Onni.filters!(:new_checkout, everyone: true, groups: %w[staff beta_testers],
      actors: [Onni::Actor.id(actor)], level: 100)
    expect(Onni.pending?(:new_checkout)).to be(true)
    Onni.ready!(:new_checkout)
    expect(visible).to be(true)
    expect(visible(other)).to be(false)
    Onni.filters!(:new_checkout, groups: ["staff"])
    expect(visible).to be(false)
    Onni.filters!(:new_checkout, groups: ["beta_testers"], level: 0)
    expect(visible).to be(false)
  end

  it "rejects excluded actors and groups even when included" do
    Onni.filters!(:new_checkout, groups: %w[staff beta_testers], excluded_groups: ["staff"],
      excluded_actors: [Onni::Actor.id(actor)])
    Onni.ready!(:new_checkout)
    expect(visible).to be(false)
    expect(visible(other)).to be(false)
    Onni.filters!(:new_checkout, excluded_actors: nil)
    expect(visible).to be(true)
    expect(visible(other)).to be(false)
  end

  it "distinguishes absent, empty, and zero filters while masking YAML defaults" do
    definition.merge!("everyone" => true, "groups" => ["beta_testers"], "level" => 0)
    Onni.ready!(:new_checkout)
    expect(visible).to be(false)
    Onni.filters!(:new_checkout, level: nil)
    expect(visible).to be(true)
    expect(visible(other)).to be(false)
    Onni.filters!(:new_checkout, groups: [])
    expect(visible).to be(false)
    Onni.filters!(:new_checkout, groups: nil)
    expect(visible(nil)).to be(true)
    Onni.filters!(:new_checkout, everyone: false)
    expect(visible).to be(false)
  end

  it "requires actors for every configured actor filter" do
    Onni.filters!(:new_checkout, everyone: true)
    Onni.ready!(:new_checkout)
    expect(visible(nil)).to be(true)
    {groups: ["beta_testers"], actors: [Onni::Actor.id(actor)],
     excluded_groups: [], excluded_actors: [], level: 100}.each do |key, value|
      Onni.filters!(:new_checkout, **{key => value})
      expect(visible(nil)).to be(false)
      Onni.filters!(:new_checkout, **{key => nil})
    end
  end

  it "parks and resumes the same composed experiment without resetting settings" do
    definition.merge!("type" => "experiment", "variants" => {"control" => 100})
    Onni.filters!(:new_checkout, groups: ["beta_testers"], level: 100)
    Onni.variants!(:new_checkout, treatment: 100)
    Onni.ready!(:new_checkout)
    expect(Onni.variant(:new_checkout, actor, record_stats: false)).to eq(:treatment)
    expect(Onni.variant(:new_checkout, other, record_stats: false)).to be_nil
    Onni.preload!(:new_checkout)
    Onni.park!(:new_checkout)
    expect(visible).to be(false)
    expect(Onni.variant(:new_checkout, actor, record_stats: false)).to be_nil
    Onni.filters!(:new_checkout, excluded_actors: [Onni::Actor.id(other)])
    expect(Onni.parked?(:new_checkout)).to be(true)
    Onni.ready!(:new_checkout)
    expect(Onni.variant(:new_checkout, actor, record_stats: false)).to eq(:treatment)
    expect(Onni.variant(:new_checkout, other, record_stats: false)).to be_nil
    Onni.clear!(:new_checkout)
    Onni.ready!(:new_checkout)
    expect(visible).to be(false)
    expect(Onni.variants(:new_checkout)).to eq("control" => 100)
  end

  it "rejects a whole malformed update before changing any settings" do
    Onni.filters!(:new_checkout, everyone: true)
    [{everyone: "true"}, {level: 101}, {level: "50"}, {groups: [nil]},
      {excluded_actors: "User;7"}, {unknown: true}].each do |invalid|
      expect { Onni.filters!(:new_checkout, groups: ["staff"], **invalid) }.to raise_error(ArgumentError)
    end
    Onni.ready!(:new_checkout)
    expect(visible(nil)).to be(true)
    expect { Onni.filters!(:missing, everyone: true) }.to raise_error(KeyError)
  end

  it "does not freeze gate values owned by a custom adapter" do
    Onni.configuration.cache = nil
    gates = [{"key" => "groups", "value" => +"beta_testers"}]
    allow(Onni.adapter).to receive(:gates_snapshot_for).and_return(gates)
    expect(visible).to be(true)
    gates.first.fetch("value").replace("staff")
    expect(visible).to be(false)
  end
end
