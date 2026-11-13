# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/active_record"
require_relative "../../lib/generators/onni/install_generator"

RSpec.describe Onni::Generators::InstallGenerator, type: :generator do
  it "writes migration, features.yml, and initializer into a destination root" do
    Dir.mktmpdir("onni-install") do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      FileUtils.mkdir_p(File.join(dir, "config/initializers"))

      generator = described_class.new([], {quiet: true}, destination_root: dir)
      generator.invoke_all

      migration = Dir[File.join(dir, "db/migrate/*create_onni_features.rb")].first
      expect(migration).to be_a(String)
      expect(File.read(migration)).to include("create_table :onni_features")
      expect(File.read(File.join(dir, "config/features.yml"))).to include("new_checkout")
      initializer = File.read(File.join(dir, "config/initializers/onni.rb"))
      expect(initializer).to include("Onni.configure")
      expect(initializer).to include("stats_sample_rate = 0.1")
      expect(initializer).to include("stats_buffer = true")
      expect(initializer).to include("ActiveAdminRoutes.draw")
      expect(initializer).to include('subscribe(/\\.onni$/)')
    end
  end
end
