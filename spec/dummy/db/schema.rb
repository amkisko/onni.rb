# frozen_string_literal: true

ActiveRecord::Schema.define(version: 20_261_112_000_000) do
  create_table :onni_features, force: :cascade do |t|
    t.string :key, null: false
    t.timestamps
  end
  add_index :onni_features, :key, unique: true

  create_table :onni_feature_gates, force: :cascade do |t|
    t.string :feature_key, null: false
    t.string :key, null: false
    t.text :value, null: false
    t.timestamps
  end
  add_index :onni_feature_gates, [:feature_key, :key, :value],
    unique: true, name: "index_onni_feature_gates_unique"

  create_table :onni_feature_stat_buckets, force: :cascade do |t|
    t.string :feature_key, null: false
    t.string :period, null: false, default: "hour"
    t.datetime :period_start, null: false
    t.bigint :enabled_hits, null: false, default: 0
    t.bigint :disabled_hits, null: false, default: 0
    t.timestamps
  end
  add_index :onni_feature_stat_buckets, [:feature_key, :period, :period_start],
    unique: true, name: "index_onni_feature_stats_unique"
  add_index :onni_feature_stat_buckets, :period_start,
    name: "index_onni_feature_stats_on_period_start"
end

