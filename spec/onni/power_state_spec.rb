# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ready, pending, and parked power" do
  let(:actor) { Struct.new(:id).new(7) }

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.reset_request!
    allow(Onni::Registry).to receive(:config).and_return(
      "new_checkout" => {"everyone" => true},
      "search_v2" => {"level" => 100},
      "audience" => {"groups" => ["beta_testers"]},
      "experiment" => {"type" => "experiment", "everyone" => true, "variants" => {"control" => 100}}
    )
  end

  def expect_state(name, state)
    %i[ready pending parked].each do |candidate|
      expect(Onni.public_send(:"#{candidate}?", name)).to eq(candidate == state)
      expect(Onni[name].public_send(:"#{candidate}?")).to eq(candidate == state)
    end
    expect(Onni[name].power_state).to eq(state)
  end

  it "moves pending -> ready -> parked -> ready -> pending" do
    expect_state(:new_checkout, :pending)
    expect(Onni.visible?(:new_checkout)).to be(false)
    Onni.ready!(:new_checkout)
    expect_state(:new_checkout, :ready)
    expect(Onni.visible?(:new_checkout)).to be(true)
    Onni.park!(:new_checkout)
    expect_state(:new_checkout, :parked)
    expect(Onni.visible?(:new_checkout)).to be(false)
    Onni.ready!(:new_checkout)
    expect_state(:new_checkout, :ready)
    Onni.clear!(:new_checkout)
    expect_state(:new_checkout, :pending)
  end

  it "can park a never-started flag and clear that explicit decision" do
    Onni.park!(:new_checkout)
    expect_state(:new_checkout, :parked)
    Onni.clear!(:new_checkout)
    expect_state(:new_checkout, :pending)
  end

  it "keeps a soft zero ready and restores YAML defaults after clear" do
    Onni.level!(:search_v2, 0)
    expect_state(:search_v2, :ready)
    expect(Onni.visible?(:search_v2, actor)).to be(false)
    Onni.park!(:search_v2)
    expect_state(:search_v2, :parked)
    expect(Onni.level(:search_v2)).to eq(0)
    Onni.clear!(:search_v2)
    expect_state(:search_v2, :pending)
    Onni.ready!(:search_v2)
    expect(Onni.visible?(:search_v2, actor, record_stats: false)).to be(true)
  end

  it "preserves each power state when changing weights or dropping a slice" do
    {experiment: -> { Onni.variants!(:experiment, treatment: 100) },
     audience: -> { Onni.drop_group!(:audience, :beta_testers) }}.each do |name, change|
      change.call
      expect_state(name, :pending)
      Onni.ready!(name)
      change.call
      expect_state(name, :ready)
      Onni.park!(name)
      change.call
      expect_state(name, :parked)
    end
  end

  it "does not confuse a ready expired flag with parked power" do
    Onni::Registry.config["new_checkout"]["expires_at"] = "2000-01-01"
    Onni.ready!(:new_checkout)
    expect_state(:new_checkout, :ready)
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
  end

  it "fails closed for unknown names without inventing a power state" do
    expect_state(:missing, nil)
    expect(Onni.visible?(:missing, actor)).to be(false)
    expect(Onni.variant(:missing, actor)).to be_nil
    expect { Onni.park!(:missing) }.to raise_error(KeyError)
  end
end
