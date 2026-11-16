# frozen_string_literal: true

module Onni
  module Admin
    module GraphQL
      module Access
        module_function

        # Map host OAuth or device scopes onto Onni capability names for
        # graphql_capabilities. Native onni:read / onni:write scopes pass through.
        def map_capabilities(scopes, read: [], write: [])
          present = Array(scopes).filter_map { |scope|
            name = scope.to_s.strip
            name unless name.empty?
          }
          mapped = []
          mapped << "onni:read" if present.include?("onni:read") || Array(read).any? { |scope| present.include?(scope.to_s) }
          mapped << "onni:write" if present.include?("onni:write") || Array(write).any? { |scope| present.include?(scope.to_s) }
          mapped
        end

        def allowed?(context, action)
          capable?(context, action) && host_authorized?(context) && page_authorized?(context, action)
        end

        def capable?(context, action)
          required = (action == :read) ? ["onni:read"] : ["onni:read", "onni:write"]
          required.all? { |key| ::ActiveAdmin::GraphQL::Capability.granted?(context, key) }
        end

        def host_authorized?(context)
          controller = context[:request]&.get_header("action_controller.instance")
          !!controller&.instance_exec(&Onni.configuration.admin_authorized)
        end

        def page_authorized?(context, action)
          namespace = context[:namespace]
          return false unless namespace

          page = context[:onni_features_page] ||= namespace.resources.find do |resource|
            resource.is_a?(::ActiveAdmin::Page) && resource.name == "Features"
          end
          !!(page && context[:auth]&.authorized?(page, action, page))
        end

        def authorize!(context, action)
          return true if allowed?(context, action)

          raise ::GraphQL::ExecutionError.new("Not authorized for Onni", extensions: {code: "FORBIDDEN"})
        end
      end
    end
  end
end
