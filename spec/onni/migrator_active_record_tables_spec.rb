# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Migrator::ActiveRecordTables do
  let(:connection) do
    Class.new do
      def quote_table_name(name) = %("#{name}")
      def quote_column_name(name) = %("#{name}")

      def select_values(_sql)
        %w[new_checkout search_v2]
      end

      def select_all(_sql)
        [
          {"feature_key" => "new_checkout", "key" => "boolean", "value" => "true"},
          {"feature_key" => "search_v2", "key" => "groups", "value" => "beta_testers"}
        ]
      end
    end.new
  end

  def source_for(connection)
    described_class.new(
      connection: connection,
      features_table: "legacy_features",
      gates_table: "legacy_gates"
    )
  end

  it "reads feature keys and gates from configured ActiveRecord tables" do
    source = source_for(connection)

    expect(source.feature_keys).to eq(%w[new_checkout search_v2])
    expect(source.gates).to eq([
      {feature_key: "new_checkout", key: "boolean", value: "true"},
      {feature_key: "search_v2", key: "groups", value: "beta_testers"}
    ])
  end

  it "quotes configured table and column names when querying" do
    sql = []
    quoting = Class.new do
      define_method(:quote_table_name) do |name|
        sql << [:table, name]
        "`#{name}`"
      end
      define_method(:quote_column_name) do |name|
        sql << [:column, name]
        "`#{name}`"
      end
      define_method(:select_values) do |query|
        sql << [:values, query]
        []
      end
      define_method(:select_all) do |query|
        sql << [:all, query]
        []
      end
    end.new

    source = described_class.new(
      connection: quoting,
      features_table: "legacy_features",
      gates_table: "legacy_gates",
      feature_key_column: "name",
      gate_feature_column: "feature_name",
      gate_key_column: "gate",
      gate_value_column: "payload"
    )
    source.feature_keys
    source.gates

    expect(sql).to include([:table, "legacy_features"], [:table, "legacy_gates"])
    expect(sql).to include([:column, "name"], [:column, "feature_name"], [:column, "gate"], [:column, "payload"])
    values_sql = sql.find { |entry| entry[0] == :values }[1]
    all_sql = sql.find { |entry| entry[0] == :all }[1]
    expect(values_sql).to include("`legacy_features`").and include("`name`")
    expect(all_sql).to include("`legacy_gates`").and include("AS feature_key").and include("AS key").and include("AS value")
  end

  it "imports through Onni.migrate! with boolean mapped to powered" do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.configuration.stats_enabled = false
    allow(Onni::Registry).to receive(:definition).and_return("type" => "boolean")
    allow(Onni::Registry).to receive(:known?) { |name| name.to_s == "new_checkout" }
    allow(Onni::Registry).to receive(:require_definition!) { |name|
      raise KeyError unless name.to_s == "new_checkout"
    }

    result = Onni.migrate!(source_for(connection))
    expect(result).to include(features: 1, gates: 1)
    expect(Onni.adapter.gates_for(:new_checkout)).to include({"key" => "powered", "value" => "true"})
  end
end
