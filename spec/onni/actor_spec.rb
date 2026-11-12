# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Actor do
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

  it "builds a stable actor id from class and id" do
    expect(described_class.id(user_class.new(42))).to eq("User;42")
  end

  it "prefers feature_actor_id when present" do
    actor = Struct.new(:feature_actor_id).new("Account;9")
    expect(described_class.id(actor)).to eq("Account;9")
  end

  it "assigns the same percentage bucket for the same actor and feature" do
    user = user_class.new(7)
    first = described_class.percentage_value(user, "demo")
    second = described_class.percentage_value(user, "demo")
    expect(first).to eq(second)
    expect(first).to be_between(0, 99)
  end

  it "picks a weighted variant deterministically" do
    user = user_class.new(7)
    variants = {"control" => 50, "treatment" => 50}
    first = described_class.variant_for(user, "demo", variants)
    expect(described_class.variant_for(user, "demo", variants)).to eq(first)
    expect(%i[control treatment]).to include(first)
  end

  it "falls back to the last variant when weights do not cover the score" do
    user = user_class.new(7)
    expect(described_class.variant_for(user, "demo", {"control" => 0, "treatment" => 0})).to eq(:treatment)
  end
end
