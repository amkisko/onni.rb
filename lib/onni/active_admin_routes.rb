# frozen_string_literal: true

module Onni
  # Draw after `ActiveAdmin.routes(self)` so `/admin/features/:key` reaches the
  # Features page show action. Reserved page_action names stay on their AA paths.
  module ActiveAdminRoutes
    RESERVED_KEYS = %w[ready park pending visible show skip feature update_feature stats].freeze
    KEY_PATTERN = /[A-Za-z0-9_.:-]+/

    module_function

    def draw(router)
      router.instance_eval do
        get "/admin/features/:key",
          to: "admin/features#feature",
          as: :admin_feature,
          constraints: ->(req) {
            key = req.path_parameters[:key].to_s
            Onni::ActiveAdminRoutes::KEY_PATTERN.match?(key) &&
              !Onni::ActiveAdminRoutes::RESERVED_KEYS.include?(key)
          }
      end
    end

    def feature_path_helper(view, key, **options)
      if view.respond_to?(:admin_feature_path) && !RESERVED_KEYS.include?(key.to_s)
        view.admin_feature_path(key, **options)
      else
        view.admin_features_feature_path(**options.merge(key: key))
      end
    end
  end
end
