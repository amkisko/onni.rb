# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::ActiveAdminRoutes do
  def recognize(routes, path)
    routes.recognize_path(path, method: :get)
  end

  it "draws a vanity path to the ActiveAdmin Features page controller" do
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { Onni::ActiveAdminRoutes.draw(self) }

    expect(recognize(routes, "/admin/features/demo")).to include(
      controller: "admin/features", action: "feature", key: "demo"
    )
    expect {
      recognize(routes, "/admin/features/ready")
    }.to raise_error(ActionController::RoutingError)
  end

  it "normalizes custom namespace path prefixes that include a leading slash" do
    ns = ActiveAdmin.application.namespaces[:admin]
    allow(ns).to receive(:route_options).and_return({path: "/desk"})
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { Onni::ActiveAdminRoutes.draw(self) }

    expect(recognize(routes, "/desk/features/demo")).to include(
      controller: "admin/features", action: "feature", key: "demo"
    )
  end

  it "requires a registered Features page in the ActiveAdmin namespace" do
    routes = ActionDispatch::Routing::RouteSet.new
    expect {
      routes.draw { Onni::ActiveAdminRoutes.draw(self, namespace: :missing_desk) }
    }.to raise_error(ArgumentError, /Unknown ActiveAdmin namespace/)
  end

  it "prefers vanity helpers when drawn and falls back to the page action path" do
    view = Object.new
    def view.admin_features_feature_path(**options)
      "/admin/features/feature?key=#{options.fetch(:key)}"
    end

    expect(described_class.feature_path_helper(view, "demo")).to eq("/admin/features/feature?key=demo")

    def view.admin_feature_path(key, **)
      "/admin/features/#{key}"
    end
    expect(described_class.feature_path_helper(view, "demo")).to eq("/admin/features/demo")
    expect(described_class.feature_path_helper(view, "ready")).to eq("/admin/features/feature?key=ready")
  end
end
