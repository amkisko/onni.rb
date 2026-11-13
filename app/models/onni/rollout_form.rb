# frozen_string_literal: true

module Onni
  class RolloutForm
    include ActiveModel::Model

    attr_accessor :level, :group_name, :group_action, :variant_weight

    def apply!(name, parameters)
      definition = Registry.require_definition!(name)
      case Settings.type(definition)
      when "percentage" then apply_level!(name, parameters)
      when "group" then apply_group!(name, parameters)
      when "experiment" then apply_variants!(name, parameters)
      else
        raise ArgumentError, "No rollout settings for this type"
      end
    end

    def self.model_name
      ActiveModel::Name.new(self, nil, "Feature")
    end

    private

    def apply_level!(name, parameters)
      raise ArgumentError, "Choose a level" unless parameters[:level].present?

      Onni.level!(name, parameters[:level])
    end

    def apply_group!(name, parameters)
      group = parameters[:group_name].to_s
      case parameters[:group_action]
      when "visible" then Onni.visible_group!(name, group)
      when "drop" then Onni.drop_group!(name, group)
      else raise ArgumentError, "Choose a group action"
      end
    end

    def apply_variants!(name, parameters)
      weights = parameters[:variants]
      raise ArgumentError, "Choose variant weights" unless weights.respond_to?(:to_unsafe_h)

      Onni.variants!(name, weights.to_unsafe_h.transform_values { |value| Integer(value) })
    end
  end
end
