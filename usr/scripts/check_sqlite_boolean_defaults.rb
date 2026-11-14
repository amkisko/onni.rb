# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "tmpdir"
require "json"

class BooleanDefaultProbe < ActiveRecord::Base
  self.table_name = "boolean_default_probes"
end

Dir.mktmpdir("onni-boolean-defaults-") do |directory|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(directory, "probe.sqlite3"))
  connection = ActiveRecord::Base.connection
  results = %w[TRUE FALSE 1 0].to_h do |literal|
    connection.drop_table(:boolean_default_probes, if_exists: true)
    connection.execute("CREATE TABLE boolean_default_probes (id INTEGER PRIMARY KEY, active BOOLEAN DEFAULT #{literal} NOT NULL)")
    BooleanDefaultProbe.reset_column_information
    [literal, {column_default: BooleanDefaultProbe.columns_hash.fetch("active").default,
               model_default: BooleanDefaultProbe.new.active}]
  end
  puts JSON.pretty_generate(active_record: ActiveRecord::VERSION::STRING, defaults: results)
ensure
  ActiveRecord::Base.connection_pool.disconnect!
end
