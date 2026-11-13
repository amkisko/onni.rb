# frozen_string_literal: true

require "spec_helper"
require "timeout"

RSpec.describe "Gate cache consistency" do
  around do |example|
    previous_cache = Onni.configuration.cache
    example.run
  ensure
    Onni.configuration.cache = previous_cache
    Onni.reset_request!
  end

  before do
    Onni.configuration.cache = ActiveSupport::Cache::MemoryStore.new
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.reset_request!
    allow(Onni::Registry).to receive(:config).and_return("new_checkout" => {"type" => "boolean"})
    Onni.ready!(:new_checkout)
  end

  it "does not let a delayed fill restore gates after a committed skip" do
    ready = Queue.new
    release = Queue.new
    allow(Onni.adapter).to receive(:gates_snapshot_for).and_wrap_original do |original, name|
      gates = original.call(name)
      if Thread.current[:slow_gate_read]
        ready << true
        release.pop
      end
      gates
    end
    reader = Thread.new do
      Thread.current[:slow_gate_read] = true
      Onni.visible?(:new_checkout, record_stats: false)
    end
    Timeout.timeout(5) { ready.pop }
    Onni.park!(:new_checkout)
    release << true
    expect(reader.value).to be(true)
    expect(Onni.visible?(:new_checkout, record_stats: false)).to be(false)
    expect(Onni.ready?(:new_checkout)).to be(false)
  ensure
    release << true if release
    reader&.join(5)
  end

  it "rebuilds after eviction from adapter state and the YAML definition" do
    expect(Onni.visible?(:new_checkout, record_stats: false)).to be(true)
    Onni.configuration.cache.clear
    Onni.reset_request!
    expect(Onni.visible?(:new_checkout, record_stats: false)).to be(true)
    Onni.adapter = Onni::Adapters::Memory.new
    expect(Onni.visible?(:new_checkout, record_stats: false)).to be(false)
  end

  it "keeps a committed skip successful when obsolete-entry cleanup fails" do
    expect(Onni.visible?(:new_checkout, record_stats: false)).to be(true)
    allow(Onni.configuration.cache).to receive(:delete).and_raise(IOError, "cleanup unavailable")
    expect { Onni.park!(:new_checkout) }.not_to raise_error
    expect(Onni.visible?(:new_checkout, record_stats: false)).to be(false)
  end
end
