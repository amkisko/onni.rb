# frozen_string_literal: true

module Onni
  class RolloutForm
    include ActiveModel::Model

    FILTER_LABELS = {
      "everyone" => "Everyone", "groups" => "Include groups", "actors" => "Include actors",
      "excluded_groups" => "Exclude groups", "excluded_actors" => "Exclude actors", "level" => "Percentage"
    }.freeze

    attr_accessor :variant_weight

    def apply!(name, parameters)
      Registry.require_definition!(name)
      if parameters[:remove_filter]
        Onni.filters!(name, **{parameters[:remove_filter] => nil})
      elsif parameters[:filter]
        key = parameters[:filter].to_s
        value = filter_value(key, parameters[:value])
        Onni.filters!(name, **{key => value})
      elsif parameters[:variants]
        apply_variants!(name, parameters)
      else
        raise ArgumentError, "Choose a setting"
      end
    end

    def self.model_name
      ActiveModel::Name.new(self, nil, "Feature")
    end

    private

    def filter_value(key, value)
      raise ArgumentError, "Unknown audience filter" unless FILTER_LABELS.key?(key)

      case key
      when "everyone"
        raise ArgumentError, "Choose everyone setting" unless %w[true false].include?(value)

        value == "true"
      when "level" then Integer(value, 10)
      else value.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?).uniq
      end
    end

    def apply_variants!(name, parameters)
      weights = parameters[:variants]
      raise ArgumentError, "Choose variant weights" unless weights.respond_to?(:to_unsafe_h)

      Onni.variants!(name, weights.to_unsafe_h.transform_values { |value| Integer(value, 10) })
    end
  end
end
