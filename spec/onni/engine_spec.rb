# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::Engine do
  it "registers configure, Zeitwerk ignore, ActiveAdmin load, and i18n initializers" do
    names = described_class.initializers.map(&:name)
    expect(names).to include(
      "onni.configure",
      "onni.configure_zeitwerk",
      "onni.load_active_admin",
      "onni.i18n"
    )
  end

  describe ".boot_sync_registry!" do
    around do |example|
      previous_adapter = Onni.configuration.adapter
      example.run
    ensure
      Onni.configuration.adapter = previous_adapter
      Onni.reset_adapter!
    end

    it "skips when a db rake task is running" do
      allow(Rake.application).to receive(:top_level_tasks).and_return(["db:migrate"])
      expect(Onni).not_to receive(:sync_registry!)
      described_class.boot_sync_registry!
    end

    it "syncs the registry for non-memory adapters in local environments" do
      Onni.configuration.adapter = :active_record
      Onni.reset_adapter!
      expect(Onni).to receive(:sync_registry!).and_return(true)
      described_class.boot_sync_registry!
    end

    it "swallows missing-database errors during boot sync" do
      Onni.configuration.adapter = :active_record
      Onni.reset_adapter!
      allow(Onni).to receive(:sync_registry!).and_raise(ActiveRecord::NoDatabaseError)
      expect { described_class.boot_sync_registry! }.not_to raise_error
    end
  end
end
