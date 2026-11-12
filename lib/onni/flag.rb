# frozen_string_literal: true

require "date"

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

    def expires_on
      return if expires_at.blank?

      Date.parse(expires_at.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def expires_full
      date = expires_on
      return expires_at.to_s if date.nil? && expires_at.present?

      date&.iso8601
    end

    def expires_summary(now: Time.now.utc)
      date = expires_on
      return if date.nil?

      days = (date - now.to_date).to_i
      if days.zero?
        "today"
      elsif days.abs >= 365
        years = (days / 365.0).round
        relative_count(years, "year")
      else
        relative_count(days, "day")
      end
    end

    def variants
      raw = definition["variants"] || gates_variants
      return {} if raw.blank?

      raw.transform_keys(&:to_s).transform_values(&:to_i)
    end

    private

    def relative_count(count, unit)
      absolute = count.abs
      label = (absolute == 1) ? unit : "#{unit}s"
      if count.positive?
        "in #{absolute} #{label}"
      else
        "#{absolute} #{label} ago"
      end
    end

    def gates_variants
      gate = gates.find { |entry| entry["key"] == "variants" }
      return {} unless gate

      JSON.parse(gate["value"])
    rescue JSON::ParserError
      {}
    end
  end
end
