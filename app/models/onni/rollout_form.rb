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
      operation = %i[reset_signal signal stats_enabled remove_filter filter variants].find { |key| parameters[key] }
      case operation
      when :reset_signal then Onni.reset_signals!(name, parameters[:reset_signal])
      when :signal then apply_signal!(name, parameters)
      when :stats_enabled then apply_stats!(name, parameters)
      when :remove_filter then apply_filters!(name, parameters, parameters[:remove_filter] => nil)
      when :filter then apply_filter!(name, parameters)
      when :variants then apply_variants!(name, parameters)
      else raise ArgumentError, "Choose a setting"
      end
    end

    def self.model_name
      ActiveModel::Name.new(self, nil, "Feature")
    end

    private

    def apply_signal!(name, parameters)
      value = parameters[:threshold].presence
      Onni.signals!(name, **{parameters[:signal] => {threshold: value ? Integer(value, 10) : nil}})
    end

    def apply_filter!(name, parameters)
      key = parameters[:filter].to_s
      apply_filters!(name, parameters, key => filter_value(key, parameters[:value]))
    end

    def apply_filters!(name, parameters, changes)
      if parameters[:experiment].present?
        Onni.experiment_filters!(name, parameters[:experiment], **changes)
      else
        Onni.filters!(name, **changes)
      end
    end

    def apply_stats!(name, parameters)
      value = parameters[:stats_enabled]
      raise ArgumentError, "Choose counts setting" unless %w[true false].include?(value)

      Onni.stats!(name, enabled: value == "true", sample_rate: Float(parameters[:sample_rate]))
    end

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
