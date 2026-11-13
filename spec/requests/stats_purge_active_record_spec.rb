# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni stats purge ActiveRecord", type: :request do
  def create_bucket(period_start, feature_key: "demo")
    Onni::StatBucket.create!(
      feature_key: feature_key,
      period: "hour",
      period_start: period_start.utc.beginning_of_hour,
      shown_count: 1,
      skip_count: 0
    )
  end

  it "removes only buckets older than the cutoff" do
    old_bucket = create_bucket(40.days.ago)
    recent_bucket = create_bucket(2.days.ago)

    result = Onni::Stats::Purge.call(older_than: 30.days.ago, batch_size: 100)

    expect(result[:processed_count]).to eq(1)
    expect(Onni::StatBucket.exists?(old_bucket.id)).to be(false)
    expect(Onni::StatBucket.exists?(recent_bucket.id)).to be(true)
  end

  it "pages by id cursor across multiple batches" do
    create_bucket(50.days.ago)
    create_bucket(45.days.ago)
    create_bucket(40.days.ago)

    first = Onni::Stats::Purge.call(older_than: 30.days.ago, batch_size: 2, enqueue: ->(**) {})
    expect(first[:continued]).to be(true)
    expect(first[:processed_count]).to eq(2)
    expect(Onni::StatBucket.count).to eq(1)

    second = Onni::Stats::Purge.call(
      older_than: 30.days.ago,
      batch_size: 2,
      after_id: first[:after_id],
      processed_count: first[:processed_count]
    )
    expect(second[:continued]).to be(false)
    expect(second[:processed_count]).to eq(3)
    expect(Onni::StatBucket.count).to eq(0)
  end
end
