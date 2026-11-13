# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/active_record"
require_relative "../../lib/generators/onni/install_generator"
require_relative "../support/isolated_ruby"

RSpec.describe Onni::Generators::InstallGenerator, type: :generator do
  include IsolatedRuby

  it "writes migration, features.yml, and initializer into a destination root" do
    Dir.mktmpdir("onni-install") do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      FileUtils.mkdir_p(File.join(dir, "config/initializers"))

      generator = described_class.new([], {quiet: true}, destination_root: dir)
      generator.invoke_all

      migration = Dir[File.join(dir, "db/migrate/*create_onni_features.rb")].first
      expect(migration).to be_a(String)
      expect(File).to exist(File.join(dir, "config/features.yml"))
      File.write(File.join(dir, "config/features.yml"), "new_checkout:\n  description: Install fixture\n  expires_at: '2099-01-01'\n  everyone: true\n")
      result = isolated_ruby(<<~RUBY, dir, migration, coverage_name: "generated-install")
        require "onni/active_record"
        require "active_support/core_ext/numeric/time"
        require "active_support/string_inquirer"
        require "pathname"
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        ActiveRecord::Migration.verbose = false
        load ARGV.fetch(1)
        CreateOnniFeatures.new.migrate(:up)
        module Rails
          def self.root = Pathname.new(ARGV.fetch(0))
          def self.cache = nil
          def self.env = ActiveSupport::StringInquirer.new("production")
        end
        load File.join(ARGV.fetch(0), "config/initializers/onni.rb")
        visible = Onni.visible?(:new_checkout)
        buffered = Onni::StatBucket.count
        Onni.reset_request!
        puts JSON.generate(visible: visible, buffered: buffered,
          rate: Onni.configuration.stats_sample_rate, buffer: Onni.configuration.stats_buffer,
          count: Onni::StatBucket.sum(:skip_count))
      RUBY
      expect(result).to eq("visible" => false, "buffered" => 0, "rate" => 1.0, "buffer" => true, "count" => 1)
    end
  end
end
