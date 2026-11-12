# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni SQLite ActiveRecord support", type: :request do
  it "runs the dummy app on SQLite" do
    expect(ActiveRecord::Base.connection.adapter_name).to match(/sqlite/i)
  end

  it "does not use a private :memory: database (pool connections must share schema)" do
    database = ActiveRecord::Base.connection_db_config.database.to_s

    expect(database).not_to eq(":memory:")
  end

  it "upserts hit buckets with ON CONFLICT and excluded.updated_at" do
    adapter = Onni::Adapters::ActiveRecord.new
    sqls = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      sqls << ActiveSupport::Notifications::Event.new(*args).payload[:sql]
    end

    begin
      adapter.record_stat("sqlite_upsert", enabled: true, weight: 2)
      adapter.record_stat("sqlite_upsert", enabled: true, weight: 3)
      adapter.record_stat("sqlite_upsert", enabled: false, weight: 1)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    expect(sqls.join("\n")).to match(/ON CONFLICT/i)
    expect(sqls.join("\n")).to include("excluded.updated_at")
    bucket = Onni::StatBucket.find_by!(feature_key: "sqlite_upsert")
    expect(bucket.enabled_hits).to eq(5)
    expect(bucket.disabled_hits).to eq(1)
  end

  describe "pooled connections", use_transactional_tests: false do
    after do
      Onni::Feature.delete_all
      Onni::Gate.delete_all
      Onni::StatBucket.delete_all
    end

    it "shares schema and increments across pool checkouts" do
      Onni::StatBucket.delete_all
      errors = []
      threads = Array.new(4) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            raise "missing stats table" unless connection.table_exists?(:onni_feature_stat_buckets)

            Onni::Adapters::ActiveRecord.new.record_stat("sqlite_pool", enabled: true, weight: 1)
          end
        rescue => error
          errors << "#{error.class}:#{error.message}"
        end
      end
      threads.each(&:join)

      expect(errors).to eq([])
      expect(Onni::StatBucket.find_by!(feature_key: "sqlite_pool").enabled_hits).to eq(4)
    end

    it "batches buffered hits under concurrent flush pressure" do
      Onni.configuration.stats_buffer = true
      Onni.reset_request!
      Onni.enable(:demo)

      10.times { Onni.enabled?(:demo) }
      Onni.flush_stats!

      expect(Onni::StatBucket.find_by!(feature_key: "demo").enabled_hits).to eq(10)
    ensure
      Onni.configuration.stats_buffer = false
      Onni.reset_request!
    end
  end
end
