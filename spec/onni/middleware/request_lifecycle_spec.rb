# frozen_string_literal: true

require "rails_helper"
require "onni/middleware/request_lifecycle"

RSpec.describe Onni::Middleware::RequestLifecycle do
  around do |example|
    previous = {
      stats_enabled: Onni.configuration.stats_enabled,
      stats_sample_rate: Onni.configuration.stats_sample_rate,
      stats_buffer: Onni.configuration.stats_buffer,
      request_preload: Onni.configuration.request_preload
    }
    example.run
  ensure
    previous.each { |key, value| Onni.configuration.public_send("#{key}=", value) }
    Onni.reset_request!
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
    Onni.configuration.stats_buffer = true
    Onni.configuration.request_preload = false
    Onni.reset_request!
  end

  def call_middleware(app)
    described_class.new(app).call({})
  end

  it "flushes buffered stats after the request" do
    app = lambda do |_env|
      Onni::Stats.record("demo", shown: true)
      Onni::Stats.record("demo", shown: true)
      [200, {}, ["ok"]]
    end

    expect(Onni.adapter).to receive(:record_stats_batch).once.and_call_original
    status, = call_middleware(app)
    expect(status).to eq(200)
    expect(Onni::Stats.for("demo").sum { |bucket| bucket["shown_count"] }).to eq(2)
  end

  it "clears request state when the app raises" do
    Onni.preload!(:demo)
    expect(Onni::RequestStore.gates).not_to be_nil

    app = lambda do |_env|
      Onni::Stats.record("demo", shown: true)
      raise "boom"
    end

    expect { call_middleware(app) }.to raise_error(RuntimeError, "boom")
    expect(Onni::RequestStore.gates).to be_nil
    expect(Onni::RequestStore.stats_buffer).to be_nil
    expect(Onni::Stats.for("demo").sum { |bucket| bucket["shown_count"] }).to eq(1)
  end

  it "preloads gates when request_preload is enabled" do
    Onni.configuration.request_preload = true
    expect(Onni).to receive(:preload!).once.and_call_original

    status, = call_middleware(->(_env) { [200, {}, ["ok"]] })
    expect(status).to eq(200)
  end

  it "keeps a successful response and clears request state when stats flushing fails" do
    Onni.preload!(:demo)
    allow(Onni.adapter).to receive(:record_stats_batch).and_raise(IOError, "unavailable")
    app = lambda do |_env|
      Onni::Stats.record("demo", shown: true)
      [200, {}, ["ok"]]
    end
    expect(call_middleware(app)).to eq([200, {}, ["ok"]])
    expect(Onni::RequestStore.gates).to be_nil
    expect(Onni::RequestStore.stats_buffer).to be_nil
  end

  it "preserves the application failure when stats flushing also fails" do
    allow(Onni.adapter).to receive(:record_stats_batch).and_raise(IOError, "unavailable")
    app = lambda do |_env|
      Onni::Stats.record("demo", shown: true)
      raise "application failed"
    end
    expect { call_middleware(app) }.to raise_error(RuntimeError, "application failed")
    expect(Onni::RequestStore.stats_buffer).to be_nil
  end

  it "skips preload when request_preload is disabled" do
    Onni.configuration.request_preload = false
    expect(Onni).not_to receive(:preload!)

    call_middleware(->(_env) { [200, {}, ["ok"]] })
  end
end
