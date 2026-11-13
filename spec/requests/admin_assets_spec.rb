# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveAdmin assets", type: :request do
  it "serves the stylesheet and JavaScript referenced by the dashboard" do
    get admin_features_path

    document = Nokogiri::HTML(response.body)
    stylesheet = document.at_css('link[rel="stylesheet"]')
    expect(stylesheet).to be_present

    get stylesheet["href"]
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.body).not_to be_empty

    imports = JSON.parse(document.at_css('script[type="importmap"]').text).fetch("imports")
    expect(imports).to have_key("active_admin")
    imports.each_value do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/javascript")
      expect(response.body).not_to be_empty
    end
  end
end
