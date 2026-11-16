# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Flag, "#assignment" do
  before do
    Onni.adapter = Onni::Adapters::Memory.new
    allow(Onni::Registry).to receive(:config).and_return(
      "plain" => {"everyone" => true},
      "ab" => {"type" => "experiment", "everyone" => true},
      "ship" => {"everyone" => true, "type" => "experiment"}
    )
    allow(Onni::Delivery).to receive(:entries).and_return({})
  end

  it "labels Delivery ownership ahead of A/B experiment type" do
    expect(described_class.new("plain").assignment).to eq("None")
    expect(described_class.new("ab").assignment).to eq("Experiment")

    allow(Onni::Delivery).to receive(:entries).and_return("ship" => Class.new(Onni::Delivery))
    expect(described_class.new("ship").assignment).to eq("Delivery")
    expect(described_class.new("ship").delivery?).to be(true)
  end
end
