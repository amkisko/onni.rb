# frozen_string_literal: true

module Onni
  module CatalogueExport
    module_function

    def call(format: :yaml, runtime: false, io: nil)
      format = format.to_s
      raise ArgumentError, "Catalogue format must be yaml, json or csv" unless %w[yaml json csv].include?(format)

      rows = Registry.config.sort.map { |name, definition| row(name, definition, runtime: runtime) }
      output = encode(rows, format)
      io ? io.write(output) : output
    end

    def row(name, definition, runtime:)
      owner = Sync.synchronize { Delivery.entries[name] }
      item = {"name" => name, "definition" => definition.except("expires_at_time"),
              "experiments" => owner ? owner.experiments : {}}
      item["runtime"] = snapshot(name, definition, owner) if runtime
      item
    end

    def snapshot(name, definition, owner)
      gates = Onni.adapter.gates_for(name)
      {"power" => Settings.power_state(gates, definition).to_s,
       "filters" => Settings.filters(definition, gates).slice(*Registry::Validation::FILTER_KEYS).compact,
       "variants" => Settings.variants(definition, gates), "stats" => Stats::Policy.settings(definition, gates),
       "signals" => SignalPolicy.settings(definition, gates), "signal_levels" => SignalPolicy.read(gates, "signal_levels"),
       "experiments" => owner ? Delivery.filters(name, owner, gates) : {}}
    end

    def encode(rows, format)
      case format
      when "json" then JSON.pretty_generate(rows) + "\n"
      when "yaml" then YAML.dump(JSON.parse(JSON.generate(rows)))
      when "csv" then encode_csv(rows)
      end
    end

    def encode_csv(rows)
      lines = [csv_line(%w[name experiment definition runtime])]
      rows.each do |item|
        names = item["experiments"].empty? ? [nil] : item["experiments"].keys
        names.each { |experiment| lines << csv_line(csv_row(item, experiment)) }
      end
      lines.join
    end

    def csv_line(fields)
      fields.map { |value| value.nil? ? "" : %("#{value.to_s.gsub('"', '""')}") }.join(",") + "\r\n"
    end

    def csv_rows(csv, item)
      names = item["experiments"].empty? ? [nil] : item["experiments"].keys
      names.each do |experiment|
        csv << csv_row(item, experiment)
      end
    end

    def csv_row(item, experiment)
      definition = item.except("runtime")
      definition = definition.merge("experiments" => item["experiments"].slice(experiment)) if experiment
      [item["name"], experiment, JSON.generate(definition), item.key?("runtime") ? JSON.generate(item["runtime"]) : nil]
    end
  end
end
