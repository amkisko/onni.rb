# frozen_string_literal: true

require "spec_helper"
require "active_support/testing/time_helpers"

RSpec.describe Onni::Stats do
  include ActiveSupport::Testing::TimeHelpers

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
  end

  it "summarizes bucket storage for operators" do
    travel_to(3.days.ago) { Onni.adapter.record_stat("demo", shown: true) }
    travel_to(1.day.ago) { Onni.adapter.record_stat("demo", shown: true) }

    overview = described_class.overview

    expect(overview[:bucket_count]).to eq(2)
    expect(overview[:oldest_period_start]).to be_within(1.hour).of(3.days.ago.utc.beginning_of_hour)
    expect(overview[:retention]).to eq(Onni.configuration.stats_retention)
    expect(overview[:sample_rate]).to eq(1.0)
    expect(overview[:scale_sampled_hits]).to be(true)
  end

  it "flags when oldest buckets are past retention" do
    Onni.configuration.stats_retention = 2.days
    travel_to(5.days.ago) { Onni.adapter.record_stat("demo", shown: true) }

    expect(described_class.overview[:past_retention]).to be(true)
  end
end
