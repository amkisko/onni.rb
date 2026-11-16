# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ActiveAdmin Features dashboard", type: :system do
  it "lists flags and parks a ready feature from the browser" do
    Onni.ready!(:demo)

    visit admin_features_path

    expect(page).to have_content("Flags")
    expect(page).to have_link("demo")
    expect(page).to have_content("Experiment")
    within(:xpath, "//a[normalize-space()='demo']/ancestor::tr") do
      click_button "Park"
    end

    expect(page).to have_content("Parked demo")
    expect(Onni.parked?(:demo)).to be(true)
  end

  it "opens feature detail with Delivery assignment when a Delivery owns the flag" do
    allow(Onni::Registry).to receive(:config).and_return(
      "new_checkout" => {"expires_at" => "2099-01-01", "description" => "Checkout delivery"}
    )
    allow(Onni::Delivery).to receive(:entries).and_return({})
    Class.new(Onni::Delivery) do
      feature :new_checkout
      parked { :legacy }
      experiment(:new_flow, everyone: true) { :new }
    end

    visit admin_features_path
    expect(page).to have_content("Delivery")
    click_link "new_checkout"

    # Overview th uses CSS uppercase; assert the assignment value and Delivery panel.
    expect(page).to have_css("th", text: /Assignment/i, visible: :all)
    expect(page).to have_content("Delivery experiments")
    expect(page).to have_content("new_flow audience")
  end
end
