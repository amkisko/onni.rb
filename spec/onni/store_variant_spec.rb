# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Store do
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

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    allow(Onni::Registry).to receive(:require_definition!)
    allow(Onni::Registry).to receive_messages(
      known?: true,
      definition: {
        "description" => "Demo",
        "expires_at" => "2099-01-01",
        "variants" => {"control" => 50, "treatment" => 50}
      }
    )
  end

  it "assigns variants from YAML without a second adapter gates fetch" do
    Onni.enable(:demo)
    Onni.set_variants(:demo, {control: 10, treatment: 90})
    user = user_class.new(7)

    expect(Onni.adapter).to receive(:gates_for).once.and_call_original
    expect(%i[control treatment]).to include(described_class.variant(:demo, user))
  end

  it "reads gate variants when YAML has none, still with one gates fetch" do
    allow(Onni::Registry).to receive(:definition).and_return(
      "description" => "Demo",
      "expires_at" => "2099-01-01"
    )
    Onni.enable(:demo)
    Onni.set_variants(:demo, {control: 25, treatment: 75})
    user = user_class.new(7)

    expect(Onni.adapter).to receive(:gates_for).once.and_call_original
    expect(%i[control treatment]).to include(described_class.variant(:demo, user))
  end
end
