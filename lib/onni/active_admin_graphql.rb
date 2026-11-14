# frozen_string_literal: true

require "onni/active_admin"
gem "activeadmin-graphql", ">= 0.4.1", "< 0.5"
gem "graphql", ">= 2.6.15", "< 3"
require "activeadmin/graphql"
require "onni/admin/graphql/access"
require "onni/admin/graphql/field"
require "onni/admin/graphql/inputs"
require "onni/admin/graphql/types"
require "onni/admin/graphql/snapshot"
require "onni/admin/graphql/commands"

module Onni
  module Admin
    module GraphQL
      module_function

      def register_page!(page)
        page.graphql_field :onni, Types::Queries, null: true,
          description: "Onni operator catalogue and rollout state" do |_, context|
          Access.authorize!(context, :read)
          {}
        end
      end

      def install!(schema)
        return schema if schema.instance_variable_defined?(:@onni_operator_schema)

        ensure_dynamic_visibility!(schema)
        mutation = schema.mutation || mutation_type
        arguments_by_command = command_arguments
        ensure_fields_available!(mutation, arguments_by_command.keys)
        arguments_by_command.each do |operation, arguments|
          add_command(mutation, operation, arguments)
        end
        schema.mutation(mutation) unless schema.mutation
        schema.instance_variable_set(:@onni_operator_schema, true)
        schema
      end

      def ensure_dynamic_visibility!(schema)
        visibility = schema.visibility
        if visibility && visibility.preload? != false
          raise ArgumentError, "Configure graphql_visibility with preload: false before installing Onni"
        end
      end

      def mutation_type
        Class.new(Types::Base) do
          graphql_name "Mutation"

          def self.visible?(context)
            super && %i[ready park clear update_feature].any? { |action| Access.allowed?(context, action) }
          end
        end
      end

      def command_arguments
        {
          ready: {}, park: {reason: [String, false]}, clear: {},
          observe: {signal: [String, true], delta: [Inputs::SignedInteger, false, 1]},
          reset_signals: {signal: [String, false]},
          set_filters: {filters: [Inputs::Audience, true]},
          set_experiment_filters: {experiment: [String, true], filters: [Inputs::Audience, true]},
          set_signal_threshold: {signal: [String, true], threshold: [Inputs::SignedInteger, :nullable]},
          set_variants: {variants: [[Inputs::Variant], true]},
          set_stats: {stats: [Inputs::Stats, true]}
        }
      end

      def ensure_fields_available!(owner, operations)
        fields = owner.all_field_definitions.map(&:graphql_name)
        collision = operations.find { |operation| fields.include?("onni_#{operation}") }
        raise ArgumentError, "GraphQL field onni_#{collision} is already defined" if collision
      end

      def add_command(owner, operation, arguments)
        field = command_field(owner, operation)
        add_arguments(field, arguments)
        owner.add_field(field)
        owner.define_method(:"onni_#{operation}") { |name:, **values| Commands.call(operation, name, values) }
      end

      def command_field(owner, operation)
        name = :"onni_#{operation}"
        action = %i[ready park clear].include?(operation) ? operation : :update_feature
        Field.new(name: name, owner: owner, type: Types::Feature, null: true, action: action,
          description: "Apply Onni #{operation.to_s.tr("_", " ")} and return current state")
      end

      def add_arguments(field, arguments)
        field.argument :name, String, required: true, camelize: false
        arguments.each do |key, (type, required, default)|
          options = {required: required, camelize: false}
          options[:default_value] = default unless default.nil?
          field.argument(key, type, **options)
        end
      end
    end
  end
end
