# frozen_string_literal: true

module Onni
  # YAML `conditions` narrow a rollout after a gate matches (audience targeting).
  # They are not authorization. Supported entries:
  # - group name registered via Onni.register_group
  # - actor predicate method name ending in ? (for example beta_tester?)
  module Conditions
    module_function

    def met?(name, actor, definition: nil)
      definition ||= Registry.definition(name) || {}
      conditions = Array(definition["conditions"])
      return true if conditions.empty?
      # Global checks (no actor) only answer whether a gate is armed.
      return true if actor.nil?

      conditions.all? { |condition| match?(condition, actor) }
    end

    def match?(condition, actor)
      name = condition.to_s
      return Group.member?(name, actor) if Group.known?(name)
      return actor.public_send(name) if name.end_with?("?") && actor.respond_to?(name)

      false
    end
    private_class_method :match?
  end
end
