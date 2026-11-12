# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Group do
  after { described_class.clear! }

  it "registers an audience group from the boot empty registry" do
    # Boot sets an empty registry; register must work without a prior clear!.
    described_class.instance_variable_set(:@registry, {}.freeze)

    expect {
      described_class.register(:beta_testers) { |_actor, _name| true }
    }.not_to raise_error

    expect(described_class.known?(:beta_testers)).to be(true)
    expect(described_class.member?(:beta_testers, Object.new)).to be(true)
  end

  it "replaces a previously registered group block" do
    described_class.clear!
    described_class.register(:staff) { |_actor, _name| false }
    described_class.register(:staff) { |_actor, _name| true }

    expect(described_class.member?(:staff, Object.new)).to be(true)
  end
end
