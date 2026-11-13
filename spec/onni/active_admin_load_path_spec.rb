# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveAdmin load path" do
  it "registers app/admin before ActiveAdmin load! reads files" do
    path = Onni::Engine.root.join("app/admin").to_s
    ActiveAdmin.application.load_paths.delete(path)
    ActiveAdmin.unload!

    ActiveAdmin.load!
    Rails.application.reload_routes!

    expect(ActiveAdmin.application.load_paths).to include(path)
    expect(Rails.application.routes.url_helpers).to respond_to(:admin_features_path)
  end
end
