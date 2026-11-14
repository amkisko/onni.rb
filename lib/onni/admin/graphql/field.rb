# frozen_string_literal: true

module Onni
  module Admin
    module GraphQL
      class Field < ::ActiveAdmin::GraphQL::SchemaField
        def initialize(action: :read, **options, &block)
          @onni_action = action
          capability = (action == :read) ? "onni:read" : "onni:write"
          super(capability: capability, camelize: false, **options, &block)
        end

        def visible?(context)
          super && Access.allowed?(context, @onni_action)
        end

        def authorized?(object, arguments, context)
          super && Access.allowed?(context, @onni_action)
        end
      end
    end
  end
end
