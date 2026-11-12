# frozen_string_literal: true

module Onni
  class Flag
    attr_reader :name

    def initialize(name)
      @name = name.to_s
    end

    def exist?
      Registry.known?(name)
    end

    def enabled?(actor = nil, record_stats: true)
      Onni.enabled?(name, actor, record_stats: record_stats)
    end

    def gates
      @gates ||= Onni.adapter.gates_for(name)
    end

    def definition
      @definition ||= Registry.definition(name) || {}
    end

    def description
      definition["description"]
    end

    def expires_at
      definition["expires_at"]
    end

    def variants
      raw = definition["variants"] || gates_variants
      return {} if raw.blank?

      raw.transform_keys(&:to_s).transform_values(&:to_i)
    end

    private

    def gates_variants
      gate = gates.find { |entry| entry["key"] == "variants" }
      return {} unless gate

      JSON.parse(gate["value"])
    rescue JSON::ParserError
      {}
    end
  end
end
