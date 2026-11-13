# frozen_string_literal: true

require "spec_helper"
require "onni/rspec"

RSpec.describe Onni::RSpec do
  around do |example|
    previous_adapter = Onni.configuration.adapter
    previous_buffer = Onni.configuration.stats_buffer
    example.run
  ensure
    Onni.configuration.stats_buffer = previous_buffer
    Onni.configuration.adapter = previous_adapter
    Onni.reset_adapter!
    Onni.reset_request!
  end

  it "resets to a memory adapter and clears the request store" do
    Onni.configuration.adapter = :active_record
    Onni.reset_adapter!
    Onni.configuration.stats_buffer = true
    Onni::Stats::Buffer.add("demo", shown: true, weight: 1)

    described_class.reset!

    expect(Onni.configuration.adapter).to eq(:memory)
    expect(Onni.adapter).to be_a(Onni::Adapters::Memory)
    expect(Onni::RequestStore.stats_buffer).to be_nil
  end

  it "installs reset! as an RSpec before hook" do
    config = instance_double(::RSpec::Core::Configuration)
    expect(config).to receive(:before) do |&block|
      expect(described_class).to receive(:reset!)
      block.call
    end
    described_class.install!(config)
  end
end
