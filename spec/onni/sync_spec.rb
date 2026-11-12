# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Sync do
  around do |example|
    previous = Onni.configuration.concurrency
    example.run
  ensure
    Onni.configuration.concurrency = previous
    Onni.reset_adapter!
  end

  it "defaults to mutex locks that serialize writers across threads" do
    Onni.configuration.concurrency = :mutex
    Onni.adapter = Onni::Adapters::Memory.new
    Onni::Group.clear!

    errors = []
    threads = 8.times.map do |index|
      Thread.new do
        Onni::Group.register(:"group_#{index}") { |_actor, _| true }
        Onni.adapter.add("feature_#{index}")
        Onni.adapter.add_gate("feature_#{index}", "boolean", "true")
        Onni.adapter.record_stat("feature_#{index}", enabled: true)
      rescue => error
        errors << error
      end
    end
    threads.each(&:join)

    expect(errors).to eq([])
    expect(Onni::Group.names.size).to eq(8)
    expect(Onni.adapter.feature_keys.size).to eq(8)
  end

  it "supports cooperative fibers without overlapping critical sections" do
    Onni.configuration.concurrency = :mutex
    Onni.adapter = Onni::Adapters::Memory.new
    Onni::Group.clear!

    fiber_a = Fiber.new do
      Onni::Group.register(:alpha) { |_actor, _| true }
      Onni.adapter.add("alpha")
      Fiber.yield
      Onni.adapter.add_gate("alpha", "boolean", "true")
    end
    fiber_b = Fiber.new do
      Onni::Group.register(:beta) { |_actor, _| true }
      Onni.adapter.add("beta")
      Onni.adapter.add_gate("beta", "boolean", "true")
    end

    fiber_a.resume
    fiber_b.resume
    fiber_a.resume

    expect(Onni::Group.known?(:alpha)).to be(true)
    expect(Onni::Group.known?(:beta)).to be(true)
    expect(Onni.adapter.gates_for("alpha")).to include(hash_including("key" => "boolean"))
    expect(Onni.adapter.gates_for("beta")).to include(hash_including("key" => "boolean"))
  end

  it "allows concurrency none for single-threaded hosts" do
    Onni.configuration.concurrency = :none
    lock = described_class.new_lock
    expect(lock).to be_a(Onni::Sync::NullLock)

    called = false
    lock.synchronize { called = true }
    expect(called).to be(true)
  end

  it "publishes one shared lock under concurrent first access" do
    Onni.configuration.concurrency = :mutex
    described_class.reset!

    ready = Queue.new
    go = Queue.new
    locks = Queue.new
    threads = 16.times.map do
      Thread.new do
        ready << true
        go.pop
        locks << described_class.send(:shared_lock)
      end
    end
    16.times { ready.pop }
    16.times { go << true }
    threads.each(&:join)

    collected = 16.times.map { locks.pop }
    expect(collected.uniq.size).to eq(1)
  end

  it "rejects unknown concurrency modes" do
    expect {
      Onni.configuration.concurrency = :green_threads
    }.to raise_error(ArgumentError, /concurrency/)
  end

  it "rejects unknown concurrency when building a lock" do
    allow(Onni.configuration).to receive(:concurrency).and_return(:green_threads)
    expect { described_class.new_lock }.to raise_error(ArgumentError, /concurrency/)
  end
end
