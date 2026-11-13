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

  it "installs a before hook that resets under RSpec instance_exec" do
    config = instance_double(::RSpec::Core::Configuration)
    hook = nil
    expect(config).to receive(:before) do |&block|
      hook = block
    end

    described_class.install!(config)

    example_context = Object.new
    expect { example_context.instance_exec(&hook) }.not_to raise_error
    expect(Onni.configuration.adapter).to eq(:memory)
    expect(Onni.adapter).to be_a(Onni::Adapters::Memory)
  end
end
