# frozen_string_literal: true

module Onni
  module Audience
    module_function

    def matches?(name, actor, filters)
      return true if filters["everyone"] == true && !actor_scoped?(filters)
      return false if actor.nil?
      return false unless opened?(filters)
      return false unless actors_match?(actor, filters)

      level = filters["level"]
      return false if level && Actor.percentage_value(actor, name) >= level

      groups_match?(actor, filters)
    end

    def opened?(filters)
      filters["everyone"] == true || filters["groups"] || filters["actors"] || filters["level"]
    end
    private_class_method :opened?

    def actor_scoped?(filters)
      filters["groups"] || filters["actors"] || filters["excluded_groups"] ||
        filters["excluded_actors"] || filters["level"]
    end
    private_class_method :actor_scoped?

    def actors_match?(actor, filters)
      actors = filters["actors"]
      excluded = filters["excluded_actors"]
      return true unless actors || excluded

      identity = Actor.id(actor)
      return false if actors && !actors.include?(identity)
      return false if excluded&.include?(identity)

      true
    end
    private_class_method :actors_match?

    def groups_match?(actor, filters)
      return false if filters["groups"]&.none? { |group| Group.member?(group, actor) }
      return false if filters["excluded_groups"]&.any? { |group| Group.member?(group, actor) }

      true
    end
    private_class_method :groups_match?
  end
end
