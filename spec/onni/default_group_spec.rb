# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "active_support/testing/time_helpers"

RSpec.describe "Default group features" do
  include ActiveSupport::Testing::TimeHelpers

  let(:actor) { Struct.new(:id).new(7) }

  around do |example|
    previous_path = Onni.configuration.features_path
    previous_adapter = Onni.adapter
    Dir.mktmpdir("onni-default-group") do |directory|
      path = File.join(directory, "features.yml")
      File.write(path, <<~YAML)
        new_checkout:
          expires_at: "2027-01-01"
          description: "Checkout redesign experiment"
        search_v2:
          groups: [beta_testers]
      YAML
      Onni.configuration.features_path = path
      Onni::Registry.reload!
      travel_to(Time.utc(2026, 11, 13))
      example.run
    end
  ensure
    travel_back
    Onni.configuration.features_path = previous_path
    Onni.adapter = previous_adapter
    Onni.reset_request!
    Onni::Registry.reload!
    Onni::Group.clear!
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.reset_request!
    Onni.register_group(:beta_testers) { |candidate, _| candidate.id == 7 }
  end

  it "accepts only metadata and requires a matching group for visibility" do
    flag = Onni[:new_checkout]
    expect(flag.type).to be_nil
    expect(flag.description).to eq("Checkout redesign experiment")
    expect(flag.expires_at).to eq("2027-01-01")
    expect(flag.groups).to eq([])
    expect(flag.pending?).to be(true)

    Onni.ready!(:new_checkout)
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
    expect(Onni.visible?(:new_checkout)).to be(false)
    Onni.visible_group!(:new_checkout, :beta_testers)
    expect(Onni.visible?(:new_checkout, actor)).to be(true)
    expect(Onni.visible?(:new_checkout, Struct.new(:id).new(8))).to be(false)

    Onni.drop_group!(:new_checkout, :beta_testers)
    expect(Onni.ready?(:new_checkout)).to be(true)
    expect(Onni.visible?(:new_checkout, actor)).to be(false)
  end

  it "applies YAML group defaults after ready without requiring a type" do
    expect(Onni.visible?(:search_v2, actor)).to be(false)
    Onni.ready!(:search_v2)
    expect(Onni.visible?(:search_v2, actor)).to be(true)
    expect(Onni.visible?(:search_v2, Struct.new(:id).new(8))).to be(false)
    expect(Onni.visible?(:search_v2)).to be(false)
  end

  it "honors the expiry of a minimally declared feature" do
    Onni.visible_group!(:new_checkout, :beta_testers)
    travel_to(Time.utc(2027, 1, 2)) do
      expect(Onni.ready?(:new_checkout)).to be(true)
      expect(Onni.visible?(:new_checkout, actor)).to be(false)
    end
  end
end
