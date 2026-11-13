# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Onni adapter extensions" do
  around do |example|
    previous = Onni.configuration.adapter
    example.run
  ensure
    Onni.configuration.adapter = previous
    Onni.reset_adapter!
  end

  it "builds a registered adapter without holding the registration lock" do
    Onni.register_adapter(:custom_fixture) do
      Onni.register_group(:fixture_group) { true }
      Onni::Adapters::Memory.new
    end
    Onni.configuration.adapter = :custom_fixture
    Onni.reset_adapter!

    Onni.adapter.add("new_checkout")
    expect(Onni.adapter.exist?("new_checkout")).to be(true)
  ensure
    Onni::Group.clear!
  end

  it "rejects an unknown adapter instead of selecting an unregistered extension" do
    Onni.configuration.adapter = :unregistered_fixture
    Onni.reset_adapter!

    expect { Onni.adapter }.to raise_error(ArgumentError, /Unknown Onni adapter/)
  end

  it "requires a name and a factory for registration" do
    expect { Onni.register_adapter(:missing_factory) }.to raise_error(ArgumentError)
    expect { Onni.register_adapter("") { Onni::Adapters::Memory.new } }.to raise_error(ArgumentError)
  end
end
