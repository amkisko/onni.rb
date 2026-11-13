# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni do
  let(:user_class) do
    Class.new do
      def initialize(id, beta_tester: false)
        @id = id
        @beta_tester = beta_tester
      end

      attr_reader :id

      def beta_tester?
        @beta_tester
      end

      def self.name
        "User"
      end
    end
  end

  around do |example|
    previous_stats_enabled = described_class.configuration.stats_enabled
    previous_stats_sample_rate = described_class.configuration.stats_sample_rate
    previous_cache = described_class.configuration.cache
    previous_cache_ttl = described_class.configuration.cache_ttl
    example.run
  ensure
    described_class.configuration.stats_enabled = previous_stats_enabled
    described_class.configuration.stats_sample_rate = previous_stats_sample_rate
    described_class.configuration.cache = previous_cache
    described_class.configuration.cache_ttl = previous_cache_ttl
  end

  before do
    described_class.adapter = Onni::Adapters::Memory.new
    described_class.configuration.stats_enabled = false
    Onni::Group.clear!
    allow(Onni::Registry).to receive(:require_definition!)
    allow(Onni::Registry).to receive_messages(known?: true, definition: {"type" => "boolean", "description" => "Demo",
                                                                         "expires_at" => "2099-01-01",
                                                                         "variants" => {"control" => 50, "treatment" => 50}})
  end

  it "fails closed for unknown features" do
    allow(Onni::Registry).to receive(:known?).with(:missing).and_return(false)
    allow(Onni::Registry).to receive(:definition).with(:missing).and_return(nil)
    expect(described_class.visible?(:missing)).to be(false)
  end

  it "raises when enabling an undefined feature" do
    allow(Onni::Registry).to receive(:require_definition!).and_raise(KeyError)
    expect { described_class.ready!(:missing) }.to raise_error(KeyError)
  end

  it "shows globally and for a targeted actor" do
    user = user_class.new(42)
    expect(described_class.visible?(:demo, user)).to be(false)
    described_class.ready!(:demo)
    expect(described_class.visible?(:demo)).to be(true)
    described_class.park!(:demo)
    allow(Onni::Registry).to receive(:definition).and_return("type" => "actors")
    described_class.visible_actor!(:demo, user)
    expect(described_class.visible?(:demo, user)).to be(true)
    expect(described_class.visible?(:demo, user_class.new(99))).to be(false)
  end

  it "makes a registered audience group visible" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "group")
    described_class.register_group(:beta_testers) { |actor, _| actor.beta_tester? }
    described_class.visible_group!(:demo, :beta_testers)
    expect(described_class.visible?(:demo, user_class.new(1, beta_tester: true))).to be(true)
    expect(described_class.visible?(:demo, user_class.new(2, beta_tester: false))).to be(false)
  end

  it "rolls out by percentage of actors" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "percentage")
    described_class.level!(:demo, 100)
    expect(described_class.visible?(:demo, user_class.new(1))).to be(true)
    described_class.level!(:demo, 0)
    expect(described_class.visible?(:demo, user_class.new(1))).to be(false)
  end

  it "assigns a stable A/B variant when ready" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "experiment")
    user = user_class.new(7)
    described_class.ready!(:demo)
    described_class.variants!(:demo, {control: 50, treatment: 50})
    variant = described_class.variant(:demo, user)
    expect(%i[control treatment]).to include(variant)
    expect(described_class.variant(:demo, user)).to eq(variant)
  end

  it "applies YAML conditions after a gate matches" do
    allow(Onni::Registry).to receive(:definition).and_return(
      "type" => "boolean",
      "description" => "Demo",
      "expires_at" => "2099-01-01",
      "conditions" => ["beta_tester?"]
    )
    described_class.ready!(:demo)
    expect(described_class.visible?(:demo)).to be(true)
    expect(described_class.visible?(:demo, user_class.new(1, beta_tester: true))).to be(true)
    expect(described_class.visible?(:demo, user_class.new(2, beta_tester: false))).to be(false)
  end

  it "fails closed when expires_at is in the past" do
    allow(Onni::Registry).to receive(:definition).and_return(
      "type" => "boolean",
      "description" => "Demo",
      "expires_at" => "2000-01-01"
    )
    described_class.ready!(:demo)
    expect(described_class.visible?(:demo)).to be(false)
    expect(described_class.visible?(:demo, user_class.new(1))).to be(false)
  end

  it "fails closed when expires_at cannot be parsed" do
    allow(Onni::Registry).to receive(:definition).and_return(
      "type" => "boolean",
      "description" => "Demo",
      "expires_at" => "not-a-date"
    )
    described_class.ready!(:demo)
    expect(described_class.visible?(:demo)).to be(false)
  end

  it "drops a registered audience group visible" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "group")
    described_class.register_group(:beta_testers) { |actor, _| actor.beta_tester? }
    described_class.visible_group!(:demo, :beta_testers)
    described_class.drop_group!(:demo, :beta_testers)
    expect(described_class.visible?(:demo, user_class.new(1, beta_tester: true))).to be(false)
  end

  it "clamps percentage rollout to 0..100" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "percentage")
    described_class.level!(:demo, 250)
    expect(described_class.adapter.gates_for("demo")).to include(
      hash_including("key" => "percentage_of_actors", "value" => "100")
    )
    described_class.level!(:demo, -5)
    expect(described_class.adapter.gates_for("demo")).to include(
      hash_including("key" => "percentage_of_actors", "value" => "0")
    )
  end

  it "records shown evaluations and omits hard-off misses" do
    described_class.configuration.stats_enabled = true
    described_class.configuration.stats_sample_rate = 1.0
    described_class.ready!(:demo)
    described_class.visible?(:demo)
    described_class.park!(:demo)
    described_class.visible?(:demo)
    stats = Onni::Stats.for(:demo)
    expect(stats.sum { |bucket| bucket["shown_count"] }).to eq(1)
    expect(stats.sum { |bucket| bucket["skip_count"] }).to eq(0)
  end

  it "skips hit stats when record_stats is false" do
    described_class.configuration.stats_enabled = true
    described_class.configuration.stats_sample_rate = 1.0
    described_class.ready!(:demo)
    described_class.visible?(:demo, record_stats: false)
    expect(Onni::Stats.for(:demo)).to eq([])
  end

  it "does not reuse stale gates when the adapter is replaced under a shared cache" do
    cache = ActiveSupport::Cache::MemoryStore.new
    described_class.configuration.cache = cache
    described_class.configuration.cache_ttl = 60
    described_class.ready!(:demo)
    expect(described_class.visible?(:demo)).to be(true)

    described_class.adapter = Onni::Adapters::Memory.new
    expect(described_class.visible?(:demo)).to be(false)
  end

  it "marks a YAML-known flag as existing without adapter rows" do
    allow(Onni::Registry).to receive(:known?).with(:demo).and_return(true)
    expect(described_class[:demo].exist?).to be(true)
    expect(described_class.exist?(:demo)).to be(false)
  end

  it "removes a single actor gate when disabling for that actor" do
    allow(Onni::Registry).to receive(:definition).and_return("type" => "actors")
    user = user_class.new(42)
    other = user_class.new(99)
    described_class.visible_actor!(:demo, user)
    described_class.visible_actor!(:demo, other)
    described_class.drop_actor!(:demo, user)
    expect(described_class.visible?(:demo, user)).to be(false)
    expect(described_class.visible?(:demo, other)).to be(true)
  end

  it "lists Flag objects for adapter feature keys" do
    described_class.ready!(:demo)
    flags = described_class.features
    expect(flags.map(&:name)).to include("demo")
    expect(flags.first).to be_a(Onni::Flag)
  end

  it "delegates purge_stats! to Stats.purge!" do
    expect(Onni::Stats).to receive(:purge!).with(batch_size: 10).and_return(deleted: 0)
    expect(described_class.purge_stats!(batch_size: 10)).to eq(deleted: 0)
  end

  it "builds a memory adapter from configuration" do
    previous = described_class.configuration.adapter
    described_class.configuration.adapter = :memory
    described_class.reset_adapter!
    expect(described_class.adapter).to be_a(Onni::Adapters::Memory)
  ensure
    described_class.configuration.adapter = previous
    described_class.reset_adapter!
  end

  it "rejects an unknown adapter type" do
    previous = described_class.configuration.adapter
    described_class.configuration.adapter = :redis
    described_class.reset_adapter!
    expect { described_class.adapter }.to raise_error(ArgumentError, /adapter/)
  ensure
    described_class.configuration.adapter = previous
    described_class.reset_adapter!
  end

  it "fails closed when expiry comparison raises" do
    bad_deadline = Object.new
    def bad_deadline.<(_other)
      raise ArgumentError, "bad deadline"
    end
    allow(Onni::Registry).to receive(:definition).and_return(
      "type" => "boolean",
      "description" => "Demo",
      "expires_at" => "2099-01-01",
      "expires_at_time" => bad_deadline
    )
    described_class.ready!(:demo)
    expect(described_class.visible?(:demo)).to be(false)
  end
end
