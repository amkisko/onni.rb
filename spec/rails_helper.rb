# frozen_string_literal: true

require_relative "spec_helper"

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"

DUMMY_ROOT = Rails.root unless defined?(DUMMY_ROOT)

ActiveRecord::Base.connection_pool.with_connection do |connection|
  next if connection.table_exists?(:onni_features)

  ActiveRecord::Schema.verbose = false
  load DUMMY_ROOT.join("db", "schema.rb").to_s
end

require "rspec/rails"

Onni.configure do |config|
  config.features_path = DUMMY_ROOT.join("config/features.yml")
  config.adapter = :active_record
  config.cache = nil
  config.stats_enabled = true
  config.stats_sample_rate = 1.0
  config.admin_authorized = -> { true }
end
Onni.reset_adapter!
Onni::Registry.reload!
Onni::Group.clear!

Rails.application.reload_routes!
ActiveAdmin.application.load!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.prepend_before do
    Onni::Feature.delete_all
    Onni::Gate.delete_all
    Onni::StatBucket.delete_all
    Onni.configuration.adapter = :active_record
    Onni.reset_adapter!
    Onni::Registry.reload!
    Onni::Group.clear!
    Onni.configuration.stats_enabled = true
    Onni.configuration.stats_sample_rate = 1.0
    Onni.configuration.stats_sampler = nil
    Onni.configuration.stats_ignore = []
    Onni.configuration.stats_scale_sampled_hits = true
    Onni.configuration.stats_buffer = false
    Onni.configuration.concurrency = :mutex
    Onni.configuration.cache = nil
    Onni.configuration.admin_authorized = -> { true }
    Onni.reset_request!
  end
end
