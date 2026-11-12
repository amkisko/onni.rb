# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Group do
  around do |example|
    previous = Onni.configuration.concurrency
    example.run
  ensure
    Onni.configuration.concurrency = previous
    described_class.clear!
  end

  before { described_class.clear! }

  it "keeps register and member? consistent under thread contention" do
    Onni.configuration.concurrency = :mutex
    ready = Queue.new
    go = Queue.new

    readers = 4.times.map do
      Thread.new do
        ready << true
        go.pop
        100.times { described_class.member?(:staff, Object.new) }
      end
    end
    writer = Thread.new do
      ready << true
      go.pop
      50.times do |index|
        described_class.register(:staff) { |_actor, _| index.even? }
      end
    end

    (readers.size + 1).times { ready.pop }
    (readers.size + 1).times { go << true }
    readers.each(&:join)
    writer.join

    expect(described_class.known?(:staff)).to be(true)
  end
end
