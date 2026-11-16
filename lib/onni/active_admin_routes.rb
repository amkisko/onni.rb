# frozen_string_literal: true

module Onni
  # Optional vanity path for the Features page show action.
  #
  # Auth and authorization stay on the ActiveAdmin Features controller
  # (BaseController + page policy / admin_authorized). Drawing this route next
  # to or under an admin namespace does not inherit ActiveAdmin config by itself.
  # Call after `ActiveAdmin.routes(self)` so the page controller and helpers exist.
  # Reserved page_action names stay on their ActiveAdmin paths.
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
