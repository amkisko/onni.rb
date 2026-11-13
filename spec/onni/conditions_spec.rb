# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Conditions do
  let(:user_class) do
    Class.new do
      def initialize(beta_tester:)
        @beta_tester = beta_tester
      end

      def beta_tester?
        @beta_tester
      end
    end
  end

  after { Onni::Group.clear! }

  it "passes when there are no conditions" do
    expect(described_class.met?(:demo, user_class.new(beta_tester: false), definition: {})).to be(true)
  end

  it "passes global checks when no actor is present" do
    definition = {"conditions" => ["beta_tester?"]}
    expect(described_class.met?(:demo, nil, definition: definition)).to be(true)
  end

  it "requires every actor predicate condition" do
    definition = {"conditions" => ["beta_tester?"]}
    expect(described_class.met?(:demo, user_class.new(beta_tester: true), definition: definition)).to be(true)
    expect(described_class.met?(:demo, user_class.new(beta_tester: false), definition: definition)).to be(false)
  end

  it "accepts a registered group name as a condition" do
    Onni::Group.register(:beta_testers) { |actor, _| actor.beta_tester? }
    definition = {"conditions" => ["beta_testers"]}
    expect(described_class.met?(:demo, user_class.new(beta_tester: true), definition: definition)).to be(true)
    expect(described_class.met?(:demo, user_class.new(beta_tester: false), definition: definition)).to be(false)
  end

  it "fails closed for unknown condition tokens" do
    definition = {"conditions" => ["not_a_real_check"]}
    expect(described_class.met?(:demo, user_class.new(beta_tester: true), definition: definition)).to be(false)
  end

  it "retains scalar predicate handling and rejects false as a condition" do
    actor = user_class.new(beta_tester: true)
    expect(described_class.met?(:demo, actor, definition: {"conditions" => "beta_tester?"})).to be(true)
    expect(described_class.met?(:demo, actor, definition: {"conditions" => false})).to be(false)
  end
end
