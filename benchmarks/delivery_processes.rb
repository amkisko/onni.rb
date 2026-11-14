# frozen_string_literal: true

require "tmpdir"
require "json"
require "digest"
require_relative "../lib/onni/active_record"
require_relative "../lib/onni/active_support"

Onni.configuration.features_path = nil
Onni.configuration.adapter = :active_record
Onni.configuration.cache = nil
Onni.define!(:new_checkout, description: "Process signal pressure", expires_at: "2099-01-01",
  signals: {exception: {threshold: 10}})
writers = Integer(ENV.fetch("WRITERS", "8"))
operations = Integer(ENV.fetch("OPS", "100"))
samples = Integer(ENV.fetch("SAMPLES", "3"))
raise "at least three samples required" if samples < 3

results = Array.new(samples) do
  Dir.mktmpdir("onni-delivery-processes-") do |directory|
    database = File.join(directory, "pressure.sqlite3")
    connect = -> { ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database, timeout: 5000) }
    connect.call
    ActiveRecord::Schema.verbose = false
    load File.expand_path("../spec/dummy/db/schema.rb", __dir__)
    Onni.reset_adapter!
    Onni.ready!(:new_checkout)
    ActiveRecord::Base.connection_pool.disconnect!
    children = Array.new(writers) do
      reader, writer = IO.pipe
      pid = fork do
        reader.close
        begin
          connect.call
          Onni.reset_adapter!
          parks = 0
          subscription = ActiveSupport::Notifications.subscribe("feature_operation.onni") do |event|
            parks += 1 if event.payload[:operation] == :park
          end
          operations.times { Onni.observe!(:new_checkout, :exception) }
          writer.write(JSON.generate(parks: parks, errors: 0))
        rescue => error
          writer.write(JSON.generate(parks: parks, errors: 1, error_class: error.class.name))
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription) if subscription
          ActiveRecord::Base.connection_pool.disconnect!
          writer.close
        end
        exit! 0
      end
      writer.close
      [pid, reader]
    end
    rows = children.map do |pid, reader|
      row = JSON.parse(reader.read)
      reader.close
      _, status = Process.wait2(pid)
      raise "child failed" unless status.success?
      row
    end
    connect.call
    Onni.reset_adapter!
    result = {level: Onni.signal_level(:new_checkout, :exception), expected: writers * operations,
              parks: rows.sum { |row| row.fetch("parks") }, errors: rows.sum { |row| row.fetch("errors") },
              parked: Onni.parked?(:new_checkout)}
    ActiveRecord::Base.connection_pool.disconnect!
    result
  end
end
sources = Dir["{lib,app,sig}/**/*"].select { |path| File.file?(path) }.sort
source_digest = Digest::SHA256.hexdigest(sources.map { |path| path + "\0" + File.binread(path) }.join)
puts JSON.pretty_generate(revision: `git rev-parse HEAD`.strip, source_sha256: source_digest, writers: writers, operations: operations, samples: results)
exit 1 unless results.all? { |row| row[:level] == row[:expected] && row[:parks] == 1 && row[:errors].zero? && row[:parked] }
