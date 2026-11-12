# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveRecord adapter integration", type: :request do
  let(:user_class) do
    Class.new do
      def initialize(id)
        @id = id
      end

      attr_reader :id

      def self.name
        "User"
      end
    end
  end

  it "syncs YAML registry keys into feature rows" do
    Onni.sync_registry!

    expect(Onni::Feature.where(key: "demo")).to exist
    expect(Onni::Feature.where(key: "search_v2")).to exist
  end

  it "stores actor and percentage gates and evaluates them" do
    user = user_class.new(7)
    other = user_class.new(8)

    Onni.enable(:demo, user)
    expect(Onni.enabled?(:demo, user)).to be(true)
    expect(Onni.enabled?(:demo, other)).to be(false)

    Onni.enable_percentage_of_actors(:search_v2, 100)
    expect(Onni.enabled?(:search_v2, user)).to be(true)
  end

  it "records hit stats into ActiveRecord buckets" do
    Onni.enable(:demo)
    Onni.enabled?(:demo)
    Onni.disable(:demo)
    Onni.enabled?(:demo)

    stats = Onni::Stats.for(:demo)
    expect(stats.sum { |bucket| bucket["enabled_hits"] }).to eq(1)
    expect(stats.sum { |bucket| bucket["disabled_hits"] }).to eq(1)
  end

  it "increments an existing hour bucket on later hits" do
    adapter = Onni::Adapters::ActiveRecord.new
    adapter.record_stat("demo", enabled: true)
    adapter.record_stat("demo", enabled: true)
    adapter.record_stat("demo", enabled: false)

    bucket = Onni::StatBucket.find_by!(feature_key: "demo")
    expect(bucket.enabled_hits).to eq(2)
    expect(bucket.disabled_hits).to eq(1)
  end

  it "applies sample weight on upsert" do
    adapter = Onni::Adapters::ActiveRecord.new
    adapter.record_stat("demo", enabled: true, weight: 10)
    adapter.record_stat("demo", enabled: true, weight: 10)

    expect(Onni::StatBucket.find_by!(feature_key: "demo").enabled_hits).to eq(20)
  end

  it "lists feature keys from feature rows and gate-only keys" do
    adapter = Onni::Adapters::ActiveRecord.new
    adapter.add("demo")
    adapter.add_gate("gate_only", "boolean", "true")

    expect(adapter.feature_keys).to include("demo", "gate_only")
  end

  it "replaces all gates for a feature in one transaction" do
    adapter = Onni::Adapters::ActiveRecord.new
    adapter.add_gate("demo", "boolean", "true")
    adapter.replace_gates("demo", [{key: "groups", value: "staff"}])

    expect(adapter.gates_for("demo")).to eq([{"key" => "groups", "value" => "staff"}])
  end
end
