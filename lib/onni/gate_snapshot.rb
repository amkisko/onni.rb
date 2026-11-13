# frozen_string_literal: true

module Onni
  class GateSnapshot < Array
    attr_reader :filters, :stats

    def self.wrap(gates)
      gates.is_a?(self) ? gates : new(gates)
    end

    def initialize(gates)
      super
      @filters = legacy_filters.merge(filter_overrides)
      @filters.each_value do |value|
        value.each(&:freeze) if value.is_a?(Array)
        value.freeze
      end
      @filters.freeze
      @stats = Stats::Policy.parse(self)
      freeze
    end

    private

    def legacy_filters
      filters = {}
      %w[groups actors].each do |key|
        list = legacy_list(key)
        filters[key] = list if list
      end
      level = find { |gate| gate["key"] == "percentage_of_actors" }
      filters["level"] = level["value"].to_i.clamp(0, 100) if level
      filters
    end

    def legacy_list(key)
      override = find { |gate| gate["key"] == "#{key}_override" }
      return parse_list(override["value"]) if override

      values = select { |gate| gate["key"] == key }.map { |gate| gate["value"].dup }
      values unless values.empty?
    end

    def parse_list(value)
      parsed = JSON.parse(value)
      (parsed.is_a?(Array) && parsed.all? { |entry| entry.is_a?(String) && !entry.empty? }) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def filter_overrides
      gate = find { |entry| entry["key"] == "audience_filters" }
      return {} unless gate

      parsed = JSON.parse(gate["value"])
      Registry.validate_filters!(parsed)
      parsed
    rescue JSON::ParserError, ArgumentError
      {"groups" => []}
    end
  end
end
