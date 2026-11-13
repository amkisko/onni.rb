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

    def visible?(actor = nil, record_stats: nil)
      Onni.visible?(name, actor, record_stats: record_stats)
    end

    def power_state
      Store.power_state(name)
    end

    def ready?
      power_state == :ready
    end

    def pending?
      power_state == :pending
    end

    def parked?
      power_state == :parked
    end

    def type
      Settings.type(definition)
    end

    def level
      Settings.level(definition, gates)
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
      return unless expiry_present?

      Date.parse(expires_at.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def expires_full
      date = expires_on
      return expires_at.to_s if date.nil? && expiry_present?

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

    def groups
      Settings.list("groups", definition, gates)
    end

    def filters
      Settings.filters(definition, gates).slice(*Registry::Validation::FILTER_KEYS).compact
    end

    def stats_settings
      Stats::Policy.settings(definition, gates) if exist?
    end

    def actors
      Settings.list("actors", definition, gates)
    end

    def variants
      Settings.variants(definition, gates)
    end

    private

    def expiry_present?
      value = expires_at
      return false unless value

      value.is_a?(String) ? !value.match?(/\A[[:space:]]*\z/) : !(value.respond_to?(:empty?) && value.empty?)
    end

    def relative_count(count, unit)
      absolute = count.abs
      label = (absolute == 1) ? unit : "#{unit}s"
      if count.positive?
        "in #{absolute} #{label}"
      else
        "#{absolute} #{label} ago"
      end
    end
  end
end
