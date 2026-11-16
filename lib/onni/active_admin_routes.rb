# frozen_string_literal: true

module Onni
  # Optional vanity path for the Features page show action.
  #
  # Dashboard paths come from ActiveAdmin `register_page` / `page_action` via
  # `ActiveAdmin.routes`. This draw is optional path sugar only. Auth and
  # authorization stay on the Features `ActiveAdmin::BaseController` (namespace
  # `authentication_method`, host adapter, `admin_authorized`). Mapper placement
  # does not inherit ActiveAdmin config by itself.
  #
  # Call after `ActiveAdmin.routes(self)` on the same application mapper when a
  # host wants `/admin/features/:key`. Reserved page_action names stay on their
  # ActiveAdmin paths.
  module ActiveAdminRoutes
    RESERVED_KEYS = %w[ready park pending visible show skip feature update_feature stats].freeze
    KEY_PATTERN = /[A-Za-z0-9_.:-]+/

    module_function

    def draw(router, namespace: :admin)
      ns = active_admin_namespace(namespace)
      ensure_features_page!(ns)
      draw_vanity_feature(router, path_prefix(ns), controller_action(ns), route_helper_name(ns))
    end

    def draw_vanity_feature(router, prefix, controller, route_name)
      router.instance_eval do
        get "#{prefix}/features/:key",
          to: controller,
          as: route_name,
          constraints: ->(req) { Onni::ActiveAdminRoutes.vanity_feature_key?(req) }
      end
    end

    def vanity_feature_key?(req)
      key = req.path_parameters[:key].to_s
      KEY_PATTERN.match?(key) && !RESERVED_KEYS.include?(key)
    end

    def feature_path_helper(view, key, namespace: :admin, **options)
      if vanity_helper?(view, namespace) && !RESERVED_KEYS.include?(key.to_s)
        view.public_send(vanity_helper_name(namespace), key, **options)
      else
        view.public_send(page_feature_helper_name(namespace), **options.merge(key: key))
      end
    end

    def active_admin_namespace(name)
      ns = ActiveAdmin.application.namespaces[name.to_sym]
      raise ArgumentError, "Unknown ActiveAdmin namespace #{name.inspect}" unless ns

      ns
    end

    def ensure_features_page!(ns)
      page = ns.resources.find { |resource| resource.is_a?(::ActiveAdmin::Page) && resource.name == "Features" }
      return if page

      raise ArgumentError, "ActiveAdmin Features page is not registered in namespace #{ns.name.inspect}"
    end

    def path_prefix(ns)
      return "" if ns.root?

      segment = (ns.route_options[:path].presence || ns.name).to_s.delete_prefix("/").delete_suffix("/")
      "/#{segment}"
    end

    def controller_action(ns)
      parts = [ns.module_name&.underscore, "features"].compact
      "#{parts.join("/")}#feature"
    end

    def route_helper_name(ns)
      # Root vanity avoids bare :feature, which collides with host helpers.
      ns.root? ? :onni_feature : :"#{ns.name}_feature"
    end

    def vanity_helper_name(namespace)
      (namespace.to_sym == :root) ? :onni_feature_path : :"#{namespace}_feature_path"
    end

    def page_feature_helper_name(namespace)
      (namespace.to_sym == :root) ? :features_feature_path : :"#{namespace}_features_feature_path"
    end

    def vanity_helper?(view, namespace)
      view.respond_to?(vanity_helper_name(namespace))
    end
    private_class_method :draw_vanity_feature, :active_admin_namespace, :ensure_features_page!,
      :path_prefix, :controller_action, :route_helper_name, :vanity_helper_name,
      :page_feature_helper_name, :vanity_helper?
  end
end
