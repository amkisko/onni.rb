# frozen_string_literal: true

module Onni
  module Migrator
    # Read-only migrate! source for two SQL tables: feature keys and gate rows.
    # Pass a connection that quotes identifiers and responds to select_values /
    # select_all (ActiveRecord::Base.connection works). Table names are required.
    class ActiveRecordTables
      def initialize(
        connection:,
        features_table:,
        gates_table:,
        feature_key_column: "key",
        gate_feature_column: "feature_key",
        gate_key_column: "key",
        gate_value_column: "value"
      )
        @connection = connection
        @features_table = features_table
        @gates_table = gates_table
        @feature_key_column = feature_key_column
        @gate_feature_column = gate_feature_column
        @gate_key_column = gate_key_column
        @gate_value_column = gate_value_column
      end

      def feature_keys
        table = quote_table(@features_table)
        column = quote_column(@feature_key_column)
        @connection.select_values("SELECT #{column} FROM #{table}")
      end

      def gates
        table = quote_table(@gates_table)
        feature = quote_column(@gate_feature_column)
        key = quote_column(@gate_key_column)
        value = quote_column(@gate_value_column)
        @connection.select_all(
          "SELECT #{feature} AS feature_key, #{key} AS key, #{value} AS value FROM #{table}"
        ).map { |row| gate_row(row) }
      end

      private

      def gate_row(row)
        {
          feature_key: row["feature_key"] || row[:feature_key],
          key: row["key"] || row[:key],
          value: row["value"] || row[:value]
        }
      end

      def quote_table(name)
        @connection.quote_table_name(name)
      end

      def quote_column(name)
        @connection.quote_column_name(name)
      end
    end
  end
end
